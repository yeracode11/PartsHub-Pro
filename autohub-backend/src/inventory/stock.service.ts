import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { QwenIntentResult } from '../ai/qwen-intent.types';
import { Item } from '../items/entities/item.entity';
import { itemMatchesStockIntent } from './part-search-keywords.util';
import {
  formatStockFound,
  formatStockNotFound,
} from './stock-response.formatter';

@Injectable()
export class StockService {
  private readonly logger = new Logger(StockService.name);

  constructor(
    @InjectRepository(Item)
    private readonly itemRepository: Repository<Item>,
  ) {}

  async findMatchingItems(
    organizationId: string,
    intent: QwenIntentResult,
  ): Promise<Item[]> {
    this.logger.log(`[STOCK] search started organizationId=${organizationId}`);

    const items = await this.itemRepository.find({
      where: { organizationId },
      order: { quantity: 'DESC', createdAt: 'DESC' },
    });

    const tenantItems = items.filter(
      (item) => item.organizationId === organizationId,
    );

    const matched = tenantItems.filter((item) =>
      itemMatchesStockIntent(
        item.name,
        item.description,
        item.quantity,
        intent.vehicle,
        intent.part,
        true,
      ),
    );

    this.logger.log(`[STOCK] products found=${matched.length}`);
    return matched;
  }

  async buildCheckStockReply(
    organizationId: string,
    intent: QwenIntentResult,
  ): Promise<string> {
    const items = await this.findMatchingItems(organizationId, intent);
    if (items.length === 0) {
      return formatStockNotFound(intent);
    }
    return formatStockFound(intent, items);
  }
}
