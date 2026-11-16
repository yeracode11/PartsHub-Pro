import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type PhoneVerificationPurpose = 'register' | 'login' | 'reset_password';

export type PhoneVerificationStatus =
  | 'pending'
  | 'verified'
  | 'consumed'
  | 'expired';

/**
 * Бесплатная верификация номера через WhatsApp: пользователь сам отправляет
 * код боту (входящее сообщение), бэкенд сверяет номер отправителя.
 */
@Entity('phone_verifications')
export class PhoneVerification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Номер, который пользователь ввёл в приложении (E.164). */
  @Index()
  @Column({ type: 'varchar', length: 20 })
  phone: string;

  /** 6-значный код, который пользователь отправляет в WhatsApp. */
  @Index()
  @Column({ type: 'varchar', length: 12 })
  code: string;

  /** sha256 секрета, которым приложение опрашивает статус. */
  @Column({ type: 'varchar', length: 64 })
  secretHash: string;

  @Column({ type: 'varchar', length: 20 })
  purpose: PhoneVerificationPurpose;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: PhoneVerificationStatus;

  /** Сколько раз код пришёл с чужого номера. */
  @Column({ type: 'int', default: 0 })
  mismatchCount: number;

  @Column({ type: 'varchar', length: 128, nullable: true })
  inboundMessageId: string | null;

  @Column({ type: 'timestamptz' })
  expiresAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  verifiedAt: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;
}
