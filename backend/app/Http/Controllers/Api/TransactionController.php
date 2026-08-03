<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Transaction;
use App\Models\TransactionItem;
use App\Models\Product;
use App\Models\ActivityLog;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class TransactionController extends Controller
{
    /**
     * Get compressed logo as base64 for PDF embedding.
     * Resizes to max 150px and compresses to JPEG quality 60.
     */
    private function getCompressedLogoBase64(int $maxSize = 150, int $quality = 60): string
    {
        $logoPath = public_path('images/logo.png');
        if (!file_exists($logoPath))
            return '';

        $info = getimagesize($logoPath);
        if (!$info)
            return '';

        $src = imagecreatefrompng($logoPath);
        if (!$src)
            return '';

        $origW = imagesx($src);
        $origH = imagesy($src);
        $ratio = min($maxSize / $origW, $maxSize / $origH, 1);
        $newW = (int) round($origW * $ratio);
        $newH = (int) round($origH * $ratio);

        $dst = imagecreatetruecolor($newW, $newH);
        $white = imagecolorallocate($dst, 255, 255, 255);
        imagefill($dst, 0, 0, $white);
        imagecopyresampled($dst, $src, 0, 0, 0, 0, $newW, $newH, $origW, $origH);
        unset($src);

        ob_start();
        imagejpeg($dst, null, $quality);
        $data = ob_get_clean();
        unset($dst);

        return 'data:image/jpeg;base64,' . base64_encode($data);
    }
    public function store(Request $request)
    {
        $validated = $request->validate([
            'payment_method' => 'required|string',
            'order_type' => 'required|in:dine_in,take_away,online',
            'customer_name' => 'nullable|string',
            'notes' => 'nullable|string',
            'items' => 'required|array',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.notes' => 'nullable|string',
            'items.*.extra_charge' => 'nullable|numeric',
            'items.*.use_cup' => 'nullable|boolean',
            'amount_received' => 'nullable|numeric',
            'change_amount' => 'nullable|numeric',
            'completion_photo' => 'nullable|image|mimes:jpeg,png,jpg,webp|max:5120',
            'completion_photo_base64' => 'nullable|string',
        ]);

        try {
            DB::beginTransaction();

            $productIds = array_column($validated['items'], 'product_id');
            $productMap = Product::with('ingredients.rawMaterial')->whereIn('id', $productIds)->get()->keyBy('id');

            $subtotal = 0;
            $items = [];

            foreach ($validated['items'] as $item) {
                /** @var Product $product */
                $product = $productMap[$item['product_id']];
                $extraCharge = floatval($item['extra_charge'] ?? 0);
                $itemSubtotal = ($product->price + $extraCharge) * $item['quantity'];
                $subtotal += $itemSubtotal;

                $product->decrement('stock', $item['quantity']);

                $items[] = [
                    'product_id' => $product->id,
                    
                    'quantity' => $item['quantity'],
                    'unit_price' => $product->price,
                    'subtotal' => $itemSubtotal,
                    'notes' => $item['notes'] ?? null,
                    'extra_charge' => $extraCharge,
                ];
            }

            $tax = 0;
            $total = $subtotal + $tax;

            $transaction = Transaction::create([
                'user_id' => Auth::id(),
                'order_type' => $validated['order_type'],
                'customer_name' => $validated['customer_name'] ?? null,
                'subtotal' => $subtotal,
                'tax' => $tax,
                'total' => $total,
                'payment_method' => $validated['payment_method'],
                'payment_status' => 'unpaid',
                'kitchen_status' => 'pending',
                'notes' => $validated['notes'] ?? null,
                'amount_received' => $validated['amount_received'] ?? null,
                'change_amount' => $validated['change_amount'] ?? null,
            ]);

            // Handle Photo Saving
            if ($request->hasFile('completion_photo')) {
                File::ensureDirectoryExists(storage_path('app/public/completion_photos'));
                $path = $request->file('completion_photo')->store('completion_photos', 'public');
                $url = url('storage/' . $path);
                $transaction->update(['completion_photo' => $url]);
            } elseif ($request->filled('completion_photo_base64')) {
                $imageData = $request->completion_photo_base64;
                if (preg_match('/^data:image\/(\w+);base64,/', $imageData, $type)) {
                    $imageData = substr($imageData, strpos($imageData, ',') + 1);
                    $type = strtolower($type[1]);
                } else {
                    $type = 'jpg';
                }
                $imageData = base64_decode($imageData);
                $fileName = 'completion_' . $transaction->id . '_' . time() . '.' . $type;
                File::ensureDirectoryExists(storage_path('app/public/completion_photos'));
                $path = 'completion_photos/' . $fileName;
                Storage::disk('public')->put($path, $imageData);
                $url = url('storage/' . $path);
                $transaction->update(['completion_photo' => $url]);
            }

            $now = now();
            TransactionItem::insert(array_map(fn($item) => array_merge($item, [
                'transaction_id' => $transaction->id,
                'created_at' => $now,
                'updated_at' => $now,
            ]), $items));

            foreach ($validated['items'] as $item) {
                /** @var Product $product */
                $product = $productMap[$item['product_id']];
                $product->load('ingredients.rawMaterial');

                $itemUsesCup = isset($item['use_cup']) ? (bool)$item['use_cup'] : true;
                $cupDeducted = false;

                foreach ($product->ingredients as $ingredient) {
                    // Skip 'Cup' ingredient deduction if useCup is false
                    if (strtolower($ingredient->rawMaterial->name ?? '') === 'cup') {
                        if (!$itemUsesCup) continue;
                        $cupDeducted = true;
                    }

                    $totalUsed = $ingredient->quantity_used * $item['quantity'];
                    \App\Models\RawMaterial::adjustStock(
                        $ingredient->raw_material_id,
                        -$totalUsed,
                        'order_deduction',
                        'Pesanan #' . $transaction->id . ' - ' . $product->name . ' x' . $item['quantity'],
                        null,
                        Auth::id()
                    );
                }

                if ($itemUsesCup && !$cupDeducted) {
                    $cupMaterial = \App\Models\RawMaterial::where('name', 'Cup')->first();
                    if ($cupMaterial) {
                        \App\Models\RawMaterial::adjustStock(
                            $cupMaterial->id,
                            -$item['quantity'],
                            'order_deduction',
                            'Cup untuk Pesanan #' . $transaction->id . ' - ' . $product->name . ' x' . $item['quantity'],
                            null,
                            Auth::id()
                        );
                    }
                }
            }

            ActivityLog::log('order_created', 'Pesanan #' . $transaction->id . ' dibuat oleh ' . (Auth::user()->name ?? 'System'), [
                'transaction_id' => $transaction->id,
                'total' => $total,
                'customer_name' => $validated['customer_name'] ?? 'Tamu',
                'items_count' => count($items),
                'has_photo' => !empty($transaction->completion_photo),
            ]);

            DB::commit();

            return response()->json([
                'message' => 'Transaction successful',
                'transaction' => $transaction->load('items.product')
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Transaction failed', 'error' => $e->getMessage()], 500);
        }
    }
    private function getFilteredHistoryQuery(?string $filter = null)
    {
        $tz  = config('app.timezone', 'Asia/Makassar');
        $fmt = 'Y-m-d H:i:s';

        $query = Transaction::with(['items.product', 'table', 'user'])
            ->where('kitchen_status', 'completed');

        if (!$filter) {
            return $query->orderBy('created_at', 'desc');
        }

        if ($filter === 'daily') {
            $start = \Carbon\Carbon::now($tz)->startOfDay()->format($fmt);
            $end   = \Carbon\Carbon::now($tz)->endOfDay()->format($fmt);
            $query->whereBetween('created_at', [$start, $end]);

        } elseif ($filter === 'weekly') {
            $start = \Carbon\Carbon::now($tz)->startOfWeek(\Carbon\CarbonInterface::MONDAY)->startOfDay()->format($fmt);
            $end   = \Carbon\Carbon::now($tz)->endOfWeek(\Carbon\CarbonInterface::SUNDAY)->endOfDay()->format($fmt);
            $query->whereBetween('created_at', [$start, $end]);

        } elseif ($filter === 'monthly') {
            $start = \Carbon\Carbon::now($tz)->startOfMonth()->startOfDay()->format($fmt);
            $end   = \Carbon\Carbon::now($tz)->endOfMonth()->endOfDay()->format($fmt);
            $query->whereBetween('created_at', [$start, $end]);

        } elseif (str_starts_with($filter, 'date:')) {
            $date  = substr($filter, 5);
            $start = \Carbon\Carbon::parse($date, $tz)->startOfDay()->format($fmt);
            $end   = \Carbon\Carbon::parse($date, $tz)->endOfDay()->format($fmt);
            $query->whereBetween('created_at', [$start, $end]);

        } elseif (str_starts_with($filter, 'date_range:')) {
            $parts = explode(',', substr($filter, 11));
            if (count($parts) === 2) {
                $start = \Carbon\Carbon::parse(trim($parts[0]), $tz)->startOfDay()->format($fmt);
                $end   = \Carbon\Carbon::parse(trim($parts[1]), $tz)->endOfDay()->format($fmt);
                $query->whereBetween('created_at', [$start, $end]);
            }

        } elseif (str_starts_with($filter, 'week:')) {
            $parts = explode(',', substr($filter, 5));
            if (count($parts) === 2) {
                $year  = (int) $parts[0];
                $week  = (int) $parts[1];
                $start = \Carbon\Carbon::now($tz)->setISODate($year, $week)->startOfWeek()->startOfDay()->format($fmt);
                $end   = \Carbon\Carbon::now($tz)->setISODate($year, $week)->endOfWeek()->endOfDay()->format($fmt);
                $query->whereBetween('created_at', [$start, $end]);
            }

        } elseif (str_starts_with($filter, 'month:')) {
            $parts = explode(',', substr($filter, 6));
            if (count($parts) === 2) {
                $year  = (int) $parts[0];
                $month = (int) $parts[1];
                $start = \Carbon\Carbon::createFromDate($year, $month, 1, $tz)->startOfMonth()->startOfDay()->format($fmt);
                $end   = \Carbon\Carbon::createFromDate($year, $month, 1, $tz)->endOfMonth()->endOfDay()->format($fmt);
                $query->whereBetween('created_at', [$start, $end]);
            }
        }

        return $query->orderBy('created_at', 'desc');
    }

    public function history(Request $request)
    {
        $transactions = $this->getFilteredHistoryQuery($request->query('filter'))->limit(500)->get();
        return response()->json($transactions);
    }

    // ── Saved Transactions (draft / hold) ─────────────────────────────────────

    /**
     * Save current cart items as a "held" transaction (kitchen_status = 'saved').
     * No stock deduction happens — items are only stored for later checkout.
     */
    public function saveTransaction(Request $request)
    {
        Log::info('saveTransaction called', ['input' => $request->all()]);

        try {
            $validated = $request->validate([
                'customer_name' => 'nullable|string|max:255',
                'order_type'    => 'nullable|in:dine_in,take_away,online',
                'notes'         => 'nullable|string',
                'items'         => 'required|array|min:1',
                'items.*.product_id' => 'required|integer',
                'items.*.quantity'   => 'required|integer|min:1',
                'items.*.notes'      => 'nullable|string',
                'items.*.extra_charge' => 'nullable|numeric',
            ]);
        } catch (\Illuminate\Validation\ValidationException $e) {
            Log::error('saveTransaction validation failed', ['errors' => $e->errors()]);
            return response()->json(['success' => false, 'error' => 'Validation failed', 'details' => $e->errors()], 422);
        }

        try {
            DB::beginTransaction();

            $productIds = array_column($validated['items'], 'product_id');
            $productMap = Product::whereIn('id', $productIds)->get()->keyBy('id');

            $total = 0;
            foreach ($validated['items'] as $item) {
                $product = $productMap[$item['product_id']] ?? null;
                if (!$product) continue;
                $extra = $item['extra_charge'] ?? 0;
                $total += ($product->price + $extra) * $item['quantity'];
            }

            $transaction = Transaction::create([
                'user_id'        => Auth::id(),
                'customer_name'  => $validated['customer_name'] ?? 'Tamu',
                'order_type'     => $validated['order_type'] ?? 'dine_in',
                'payment_method' => 'pending',
                'notes'          => $validated['notes'] ?? null,
                'subtotal'       => $total,
                'tax'            => 0,
                'total'          => $total,
                'kitchen_status' => 'saved',
            ]);

            foreach ($validated['items'] as $item) {
                $product = $productMap[$item['product_id']] ?? null;
                if (!$product) continue;
                $extra = $item['extra_charge'] ?? 0;
                TransactionItem::create([
                    'transaction_id' => $transaction->id,
                    'product_id'     => $item['product_id'],
                    'quantity'       => $item['quantity'],
                    'unit_price'     => $product->price + $extra,
                    'subtotal'       => ($product->price + $extra) * $item['quantity'],
                    'notes'          => $item['notes'] ?? null,
                ]);
            }

            DB::commit();
            return response()->json([
                'success' => true,
                'transaction' => $transaction->load('items.product'),
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success' => false, 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * List all saved (held) transactions for the authenticated user.
     */
    public function savedList(Request $request)
    {
        $transactions = Transaction::with(['items.product.category', 'user'])
            ->where('kitchen_status', 'saved')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json($transactions);
    }

    /**
     * Delete a saved transaction (discard held order).
     */
    public function deleteSaved(int $id)
    {
        $transaction = Transaction::where('id', $id)
            ->where('kitchen_status', 'saved')
            ->firstOrFail();

        $transaction->items()->delete();
        $transaction->delete();

        return response()->json(['success' => true]);
    }

    /**
     * Activate a saved transaction: validate stock, deduct ingredients, set status to 'pending'.
     */
    public function activateSaved(Request $request, int $id)
    {
        $validated = $request->validate([
            'payment_method' => 'required|string',
            'customer_name'  => 'nullable|string',
            'order_type'     => 'nullable|in:dine_in,take_away,online',
            'amount_received' => 'nullable|numeric',
            'change_amount'   => 'nullable|numeric',
            'use_cup'         => 'nullable|boolean',
        ]);

        $transaction = Transaction::with('items.product.ingredients.rawMaterial')
            ->where('id', $id)
            ->where('kitchen_status', 'saved')
            ->firstOrFail();

        try {
            DB::beginTransaction();

            // ── Stok bahan baku diperbolehkan minus (tidak memblokir pesanan) ──

            // ── Deduct product stock & raw materials ──────────────────────
            $useCup = (bool) $request->input('use_cup', true);
            foreach ($transaction->items as $txItem) {
                $product = $txItem->product;
                if (!$product) continue;

                $product->decrement('stock', $txItem->quantity);
                
                $cupDeducted = false;

                foreach ($product->ingredients as $ingredient) {
                    if (strtolower($ingredient->rawMaterial->name ?? '') === 'cup') {
                        if (!$useCup) continue;
                        $cupDeducted = true;
                    }

                    $totalUsed = $ingredient->quantity_used * $txItem->quantity;
                    \App\Models\RawMaterial::adjustStock(
                        $ingredient->raw_material_id,
                        -$totalUsed,
                        'order_deduction',
                        "Pesanan #{$transaction->id} – {$product->name} x{$txItem->quantity}"
                    );
                }

                // Deduct cup for drink categories if use_cup is true and not already deducted via ingredients
                if ($useCup && !$cupDeducted) {
                    $drinkCategories = ['kopi', 'non-kopi', 'coffee', 'non-coffee'];
                    $catName = strtolower($product->category->name ?? '');
                    if (in_array($catName, $drinkCategories)) {
                        $cupMaterial = \App\Models\RawMaterial::where('name', 'Cup')->first();
                        if ($cupMaterial) {
                            \App\Models\RawMaterial::adjustStock(
                                $cupMaterial->id,
                                -$txItem->quantity,
                                'order_deduction',
                                "Cup untuk Pesanan #{$transaction->id} – {$product->name} x{$txItem->quantity}"
                            );
                        }
                    }
                }
            }

            // ── Update transaction status ─────────────────────────────────
            $transaction->update([
                'kitchen_status' => 'pending',
                'payment_method' => $validated['payment_method'],
                'payment_status' => 'unpaid',
                'customer_name'  => $validated['customer_name'] ?? $transaction->customer_name,
                'order_type'     => $validated['order_type'] ?? $transaction->order_type,
                'amount_received' => $validated['amount_received'] ?? null,
                'change_amount'   => $validated['change_amount'] ?? null,
            ]);

            DB::commit();
            return response()->json(['success' => true, 'transaction' => $transaction->fresh()]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['success' => false, 'error' => $e->getMessage()], 500);
        }
    }

    private function resolveUser(Request $request)
    {
        $user = auth('sanctum')->user();

        if (!$user && $request->filled('token')) {
            $token = \Laravel\Sanctum\PersonalAccessToken::findToken($request->token);
            if ($token) {
                $user = $token->tokenable;
            }
        }

        return $user;
    }

    public function exportExcel(Request $request)
    {
        ini_set('memory_limit', '256M');
        set_time_limit(120);

        $user = $this->resolveUser($request);

        if (!$user) {
            return response()->json(['message' => 'Akses ditolak. Silakan login kembali.'], 401);
        }

        if (!\App\Models\RolePermission::isAllowed('export_history', $user->role)) {
            return response()->json(['message' => 'Akses ditolak. Anda tidak memiliki izin untuk export.'], 403);
        }

        try {
            $transactions = $this->getFilteredHistoryQuery($request->query('filter'))->limit(2000)->get();
            return \Maatwebsite\Excel\Facades\Excel::download(new \App\Exports\HistoryExport($transactions), 'history_transactions.xlsx');
        } catch (\Exception $e) {
            return response()->json(['message' => 'Export gagal: ' . $e->getMessage()], 500);
        }
    }

    public function exportPdf(Request $request)
    {
        ini_set('memory_limit', '512M');
        set_time_limit(300);

        $user = $this->resolveUser($request);

        if (!$user) {
            return response()->json(['message' => 'Akses ditolak. Silakan login kembali.'], 401);
        }

        if (!\App\Models\RolePermission::isAllowed('export_history', $user->role)) {
            return response()->json(['message' => 'Akses ditolak. Anda tidak memiliki izin untuk export.'], 403);
        }

        try {
            $filter = $request->query('filter');

            // Aggregate by day — works for any number of rows without memory issues
            $query = $this->getFilteredHistoryQuery($filter);

            $totalProcessed = (clone $query)->sum('total');
            $totalCount = (clone $query)->count();
            $startDate = (clone $query)->min('created_at');
            $endDate = (clone $query)->max('created_at');

            // Group by date (SQLite-compatible: strftime)
            $dailySummary = (clone $query)
                ->selectRaw("strftime('%Y-%m-%d', created_at) as day, COUNT(*) as trx_count, SUM(total) as day_total, SUM(CASE WHEN payment_method='cash' THEN 1 ELSE 0 END) as cash_count, SUM(CASE WHEN payment_method='qris' THEN 1 ELSE 0 END) as qris_count")
                ->groupByRaw("strftime('%Y-%m-%d', created_at)")
                ->orderByRaw("strftime('%Y-%m-%d', created_at) DESC")
                ->get();

            $generatedOn = now();
            $logoBase64 = $this->getCompressedLogoBase64();

            $pdf = \Barryvdh\DomPDF\Facade\Pdf::loadView('exports.history_pdf', [
                'dailySummary' => $dailySummary,
                'totalProcessed' => $totalProcessed,
                'totalCount' => $totalCount,
                'startDate' => $startDate ? \Carbon\Carbon::parse($startDate) : null,
                'endDate' => $endDate ? \Carbon\Carbon::parse($endDate) : null,
                'generatedOn' => $generatedOn,
                'logoBase64' => $logoBase64,
                'filter' => $filter,
            ]);

            $pdf->setPaper('A4', 'portrait');

            return $pdf->download('history_transactions.pdf');
        } catch (\Exception $e) {
            return response()->json(['message' => 'Export PDF gagal: ' . $e->getMessage()], 500);
        }
    }

    public function exportReceiptPdf(Request $request, int $id)
    {
        $user = $this->resolveUser($request);

        if (!$user) {
            return response()->json(['message' => 'Akses ditolak. Silakan login kembali.'], 401);
        }

        /** @var Transaction $transaction */
        $transaction = Transaction::with(['items.product', 'user', 'table'])->findOrFail($id);

        $logoBase64 = $this->getCompressedLogoBase64();

        $pdf = \Barryvdh\DomPDF\Facade\Pdf::loadView('exports.receipt_80mm', [
            'transaction' => $transaction,
            'logoBase64' => $logoBase64,
        ]);

        $itemCount = $transaction->items->count();
        $baseHeight = 650;
        $perItemHeight = 120;
        $calculatedHeight = $baseHeight + ($itemCount * $perItemHeight);
        $minHeight = 800;
        $pageHeight = max($minHeight, $calculatedHeight);

        $pdf->setPaper([0, 0, 226.77, $pageHeight], 'portrait');

        return $pdf->stream('receipt-' . $id . '.pdf');
    }

    public function activeOrders()
    {
        $transactions = Transaction::with(['items.product:id,name,price', 'table:id,name', 'user:id,name'])
            ->whereIn('kitchen_status', ['pending', 'processing'])
            ->orderBy('created_at', 'asc')
            ->limit(200)
            ->get();

        return response()->json($transactions);
    }

    public function updateStatus(Request $request, int $id)
    {
        $transaction = Transaction::findOrFail($id);

        $rules = [
            'kitchen_status' => 'required|in:pending,processing,completed',
            'order_type' => 'nullable|in:dine_in,take_away,online',
            'amount_received' => 'nullable|numeric',
            'change_amount' => 'nullable|numeric',
        ];

        // If status is completed, either completion_photo or completion_photo_base64 must be present
        if ($request->kitchen_status === 'completed') {
            $rules['completion_photo'] = 'required_without:completion_photo_base64|nullable|image|mimes:jpeg,png,jpg,webp|max:5120';
            $rules['completion_photo_base64'] = 'required_without:completion_photo|nullable|string';
        }

        $validated = $request->validate($rules);

        $oldStatus = $transaction->kitchen_status;
        $updateData = [
            'kitchen_status' => $validated['kitchen_status'],
            'amount_received' => $validated['amount_received'] ?? $transaction->amount_received,
            'change_amount' => $validated['change_amount'] ?? $transaction->change_amount,
        ];

        // Save order_type if provided 
        if ($request->filled('order_type')) {
            $updateData['order_type'] = $request->input('order_type');
        }

        if ($validated['kitchen_status'] === 'completed') {
            $updateData['payment_status'] = 'paid';
        }

        // Handle File upload
        if ($request->hasFile('completion_photo')) {
            if ($transaction->completion_photo) {
                $oldPath = str_replace(url('/storage'), 'public', $transaction->completion_photo);
                Storage::delete($oldPath);
            }
            File::ensureDirectoryExists(storage_path('app/public/completion_photos'));
            $path = $request->file('completion_photo')->store('completion_photos', 'public');
            $updateData['completion_photo'] = url('storage/' . $path);
        }
        // Handle Base64 upload
        elseif ($request->filled('completion_photo_base64')) {
            if ($transaction->completion_photo) {
                $oldPath = str_replace(url('/storage'), 'public', $transaction->completion_photo);
                Storage::delete($oldPath);
            }

            $imageData = $request->completion_photo_base64;
            if (preg_match('/^data:image\/(\w+);base64,/', $imageData, $type)) {
                $imageData = substr($imageData, strpos($imageData, ',') + 1);
                $type = strtolower($type[1]); // jpg, png, etc
            } else {
                $type = 'jpg'; // Default
            }

            $imageData = base64_decode($imageData);
            $fileName = 'completion_' . $id . '_' . time() . '.' . $type;
            File::ensureDirectoryExists(storage_path('app/public/completion_photos'));
            $path = 'completion_photos/' . $fileName;

            Storage::disk('public')->put($path, $imageData);
            $updateData['completion_photo'] = url('storage/' . $path);
        }

        $transaction->update($updateData);

        // Audit Log
        ActivityLog::log('order_status_updated', 'Status pesanan #' . $transaction->id . ' diubah dari ' . $oldStatus . ' ke ' . $validated['kitchen_status'], [
            'transaction_id' => $transaction->id,
            'old_status' => $oldStatus,
            'new_status' => $validated['kitchen_status'],
            'has_photo' => $request->hasFile('completion_photo'),
        ]);

        return response()->json([
            'message' => 'Status updated',
            'transaction' => $transaction->load('items.product')
        ]);
    }

    public function destroy(int $id)
    {
        $transaction = Transaction::with(['items.product.ingredients.rawMaterial'])->findOrFail($id);

        if ($transaction->payment_status === 'paid') {
            return response()->json(['message' => 'Pesanan yang sudah dibayar tidak dapat dihapus'], 400);
        }

        try {
            DB::beginTransaction();

            foreach ($transaction->items as $item) {
                // Restore product stock
                $product = $item->product;
                if ($product) {
                    $product->increment('stock', $item->quantity);

                    foreach ($product->ingredients as $ingredient) {
                        if (!$ingredient->rawMaterial)
                            continue;
                        $totalToRestore = $ingredient->quantity_used * $item->quantity;
                        \App\Models\RawMaterial::adjustStock(
                            $ingredient->raw_material_id,
                            $totalToRestore,
                            'order_cancelled',
                            'Pembatalan Pesanan #' . $transaction->id . ' - ' . $product->name . ' x' . $item->quantity,
                            null,
                            Auth::id()
                        );
                    }
                }
            }

            ActivityLog::log('order_deleted', 'Pesanan #' . $transaction->id . ' dihapus oleh ' . (Auth::user()->name ?? 'System'));

            $transaction->delete();
            DB::commit();

            return response()->json(['message' => 'Pesanan berhasil dihapus']);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Gagal menghapus pesanan', 'error' => $e->getMessage()], 500);
        }
    }
}
