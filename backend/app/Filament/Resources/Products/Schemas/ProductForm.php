<?php

namespace App\Filament\Resources\Products\Schemas;

use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Repeater;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class ProductForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->required()
                    ->live(onBlur: true)
                    ->afterStateUpdated(fn (string $operation, $state, $set) => $operation === 'create' ? $set('slug', \Illuminate\Support\Str::slug($state)) : null),
                TextInput::make('slug')
                    ->disabled()
                    ->dehydrated()
                    ->required()
                    ->unique(ignoreRecord: true),
                Select::make('category_id')
                    ->relationship('category', 'name')
                    ->searchable()
                    ->preload()
                    ->required(),
                Textarea::make('description')
                    ->columnSpanFull(),
                TextInput::make('sku')
                    ->label('SKU'),
                TextInput::make('price')
                    ->label('Harga Jual')
                    ->required()
                    ->numeric()
                    ->prefix('Rp'),
                TextInput::make('stock_display')
                    ->label('Stok (dari bahan baku)')
                    ->disabled()
                    ->dehydrated(false)
                    ->formatStateUsing(fn ($record) => $record 
                        ? $record->stock . ' porsi' 
                        : 'Otomatis dihitung setelah simpan'),
                FileUpload::make('image')
                    ->image()
                    ->disk('public')
                    ->directory('products'),
                
                Section::make('Resep Bahan Baku')
                    ->description('Tentukan bahan baku yang dibutuhkan per porsi produk ini')
                    ->icon('heroicon-o-beaker')
                    ->collapsible()
                    ->collapsed(fn (string $operation) => $operation === 'edit')
                    ->schema([
                        Repeater::make('ingredients')
                            ->relationship()
                            ->label('')
                            ->schema([
                                Select::make('raw_material_id')
                                    ->label('Bahan Baku')
                                    ->relationship('rawMaterial', 'name')
                                    ->searchable()
                                    ->preload()
                                    ->required(),
                                TextInput::make('quantity_used')
                                    ->label('Jumlah per Porsi')
                                    ->numeric()
                                    ->required()
                                    ->suffix(fn ($get) => \App\Models\RawMaterial::find($get('raw_material_id'))?->unit_small ?? ''),
                            ])
                            ->columns(['default' => 1, 'sm' => 2])
                            ->addActionLabel('+ Tambah Bahan Baku')
                            ->reorderable(false)
                            ->defaultItems(0),
                    ])
                    ->columnSpanFull(),

                Section::make('HPP & Profit')
                    ->description('Dihitung otomatis berdasarkan resep bahan baku')
                    ->icon('heroicon-o-calculator')
                    ->schema([
                        TextInput::make('hpp_display')
                            ->label('HPP (Harga Pokok Produksi)')
                            ->disabled()
                            ->dehydrated(false)
                            ->formatStateUsing(fn ($record) => $record ? 'Rp ' . number_format($record->hpp, 0, ',', '.') : 'Simpan produk terlebih dahulu'),
                        TextInput::make('profit_display')
                            ->label('Profit per Porsi')
                            ->disabled()
                            ->dehydrated(false)
                            ->formatStateUsing(fn ($record) => $record ? 'Rp ' . number_format($record->profit, 0, ',', '.') : '-'),
                        TextInput::make('margin_display')
                            ->label('Margin')
                            ->disabled()
                            ->dehydrated(false)
                            ->formatStateUsing(fn ($record) => $record && $record->price > 0
                                ? round(($record->profit / $record->price) * 100, 1) . '%'
                                : '-'),
                    ])
                    ->columns(3)
                    ->visible(fn (string $operation) => $operation === 'edit')
                    ->columnSpanFull(),
            ]);
    }
}
