import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { IncomingDoc } from './incoming-doc.entity';
import { Item } from '../../items/entities/item.entity';

@Entity('incoming_items')
export class IncomingItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Связь с накладной
  @Column({ type: 'uuid' })
  docId: string;

  @ManyToOne(() => IncomingDoc, (doc) => doc.items, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'docId' })
  doc: IncomingDoc;

  // Связь с товаром (NULL для авторазбора - создаём новый товар)
  @Column({ type: 'int', nullable: true })
  itemId: number | null;

  @ManyToOne(() => Item, { nullable: true })
  @JoinColumn({ name: 'itemId' })
  item: Item | null;

  // Название товара (для авторазбора)
  @Column({ type: 'varchar', length: 255 })
  name: string;

  // Категория
  @Column({ type: 'varchar', length: 100, nullable: true })
  category: string | null;

  // Марка/Модель авто (для Б/У)
  @Column({ type: 'varchar', length: 255, nullable: true })
  carBrand: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  carModel: string | null;

  // Номер кузова/VIN (для Б/У)
  @Column({ type: 'varchar', length: 100, nullable: true })
  vin: string | null;

  // Состояние
  @Column({ type: 'varchar', length: 50, nullable: true })
  condition: string | null; // new, used, refurbished

  // Количество
  @Column({ type: 'int', default: 1 })
  quantity: number;

  // Цена закупа
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  purchasePrice: number;

  // Ячейка хранения
  @Column({ type: 'varchar', length: 100, nullable: true })
  warehouseCell: string | null;

  // Фото товара (обязательно для Б/У)
  @Column({ type: 'jsonb', nullable: true })
  photos: string[] | null;

  // SKU/Артикул (для новых запчастей)
  @Column({ type: 'varchar', length: 100, nullable: true })
  sku: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

