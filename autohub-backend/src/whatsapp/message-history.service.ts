import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  MessageHistory,
  MessageStatus,
} from './entities/message-history.entity';

@Injectable()
export class MessageHistoryService {
  constructor(
    @InjectRepository(MessageHistory)
    private readonly historyRepository: Repository<MessageHistory>,
  ) {}

  /**
   * Сохранить запись об отправке
   */
  async create(data: Partial<MessageHistory>) {
    const history = this.historyRepository.create(data);
    return await this.historyRepository.save(history);
  }

  /**
   * Получить историю для организации
   */
  async findAll(
    organizationId: string,
    options?: { limit?: number; offset?: number },
  ) {
    const { limit = 50, offset = 0 } = options || {};

    const [items, total] = await this.historyRepository.findAndCount({
      where: { organizationId },
      relations: ['customer', 'user'],
      order: { sentAt: 'DESC' },
      take: limit,
      skip: offset,
    });

    return {
      items,
      total,
      limit,
      offset,
    };
  }

  /**
   * Получить историю по кампании
   */
  async findByCampaign(organizationId: string, campaignName: string) {
    return await this.historyRepository.find({
      where: {
        organizationId,
        campaignName,
        isBulk: true,
      },
      relations: ['customer'],
      order: { sentAt: 'DESC' },
    });
  }

  /**
   * Получить историю по клиенту
   */
  async findByCustomer(organizationId: string, customerId: number) {
    return await this.historyRepository.find({
      where: {
        organizationId,
        customerId,
      },
      order: { sentAt: 'DESC' },
    });
  }

  /**
   * Статистика отправок
   */
  async getStats(organizationId: string, period?: string) {
    const qb = this.historyRepository.createQueryBuilder('history');

    qb.where('history.organizationId = :organizationId', { organizationId });

    // Фильтр по периоду
    if (period === '7d') {
      const date = new Date();
      date.setDate(date.getDate() - 7);
      qb.andWhere('history.sentAt >= :date', { date });
    } else if (period === '30d') {
      const date = new Date();
      date.setDate(date.getDate() - 30);
      qb.andWhere('history.sentAt >= :date', { date });
    }

    const [sent, failed, total] = await Promise.all([
      qb
        .clone()
        .andWhere('history.status = :status', { status: MessageStatus.SENT })
        .getCount(),
      qb
        .clone()
        .andWhere('history.status = :status', { status: MessageStatus.FAILED })
        .getCount(),
      qb.getCount(),
    ]);

    // Топ кампании
    const topCampaigns = await this.historyRepository
      .createQueryBuilder('history')
      .select('history.campaignName', 'name')
      .addSelect('COUNT(*)', 'count')
      .where('history.organizationId = :organizationId', { organizationId })
      .andWhere('history.isBulk = :isBulk', { isBulk: true })
      .andWhere('history.campaignName IS NOT NULL')
      .groupBy('history.campaignName')
      .orderBy('count', 'DESC')
      .limit(5)
      .getRawMany();

    return {
      total,
      sent,
      failed,
      successRate: total > 0 ? ((sent / total) * 100).toFixed(2) : 0,
      topCampaigns,
    };
  }
}

