<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StockLog extends Model
{
    protected $fillable = [
        'product_id', 'raw_material_id', 'user_id', 'type', 'quantity',
        'stock_before', 'stock_after', 'reason', 'notes',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function rawMaterial()
    {
        return $this->belongsTo(RawMaterial::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Adjust stock for a product and record the log.
     */
    public static function adjustStock(
        ?int $productId = null,
        float $quantity,
        string $type = 'adjustment',
        ?string $reason = null,
        ?string $notes = null,
        ?int $userId = null,
        ?int $rawMaterialId = null
    ): static {
        $stockBefore = 0;
        $stockAfter = 0;

        if ($productId) {
            $product = Product::findOrFail($productId);
            $stockBefore = (float) $product->stock;
            $stockAfter = max(0, $stockBefore + $quantity);
            $product->update(['stock' => $stockAfter]);
        } elseif ($rawMaterialId) {
            $material = RawMaterial::findOrFail($rawMaterialId);
            $stockBefore = (float) $material->stock;
            $stockAfter = max(0, $stockBefore + $quantity);
            $material->update(['stock' => $stockAfter]);
        }

        return static::create([
            'product_id'      => $productId,
            'raw_material_id' => $rawMaterialId,
            'user_id'         => $userId ?? \Illuminate\Support\Facades\Auth::id(),
            'type'            => $type,
            'quantity'        => $quantity,
            'stock_before'    => $stockBefore,
            'stock_after'     => $stockAfter,
            'reason'          => $reason,
            'notes'           => $notes,
        ]);
    }
}
