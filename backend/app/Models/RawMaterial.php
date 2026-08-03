<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RawMaterial extends Model
{
    protected $fillable = [
        'name', 'brand', 'stock', 'unit',
        'unit_large', 'unit_small', 'conversion_value',
        'price_per_large_unit', 'price_per_small_unit',
        'min_stock', 'is_active', 'image',
    ];

    protected $casts = [
        'stock' => 'decimal:2',
        'min_stock' => 'decimal:2',
        'conversion_value' => 'decimal:2',
        'price_per_large_unit' => 'decimal:2',
        'price_per_small_unit' => 'decimal:4',
        'is_active' => 'boolean',
    ];

    protected static function booted(): void
    {
        static::saving(function (RawMaterial $material) {
            if (is_null($material->price_per_small_unit) && $material->conversion_value > 0 && $material->price_per_large_unit > 0) {
                $material->price_per_small_unit = (string) ($material->price_per_large_unit / $material->conversion_value);
            }
        });

        static::saved(function (RawMaterial $material) {
            $products = \App\Models\Product::whereHas('ingredients', function ($q) use ($material) {
                $q->where('raw_material_id', $material->id);
            })->get();
            
            foreach ($products as $product) {
                $product->syncStock();
                $product->calculateHpp(); 
            }
        });
    }

    /**
     * Adjust stock for a raw material and record the log.
     */
    public static function adjustStock(
        int $rawMaterialId,
        float $quantity,
        string $type = 'adjustment',
        ?string $reason = null,
        ?string $notes = null,
        ?int $userId = null
    ): static {
        $material = static::findOrFail($rawMaterialId);
        $stockBefore = (float) $material->stock;
        $stockAfter = $stockBefore + $quantity;

        $material->update(['stock' => $stockAfter]);

        StockLog::create([
            'raw_material_id' => $rawMaterialId,
            'user_id'         => $userId ?? \Illuminate\Support\Facades\Auth::id(),
            'type'            => $type,
            'quantity'        => $quantity,
            'stock_before'    => $stockBefore,
            'stock_after'     => $stockAfter,
            'reason'          => $reason,
            'notes'           => $notes,
        ]);

        return $material;
    }

    public function ingredients()
    {
        return $this->hasMany(ProductIngredient::class);
    }
}
