import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  MessageTemplate,
  TemplateCategory,
} from './entities/message-template.entity';

@Injectable()
export class TemplatesService {
  constructor(
    @InjectRepository(MessageTemplate)
    private readonly templateRepository: Repository<MessageTemplate>,
  ) {}

  /**
   * Создать дефолтные шаблоны для новой организации
   */
  async createDefaultTemplates(organizationId: string) {
    const defaultTemplates = [
      {
        organizationId,
        name: 'Готов к выдаче',
        category: TemplateCategory.NOTIFICATION,
        content: `Здравствуйте, {name}! 🚗

Ваш {carModel} готов к выдаче!
Приезжайте в удобное для вас время.

С уважением,
Команда {organizationName}`,
      },
      {
        organizationId,
        name: 'Напоминание ТО',
        category: TemplateCategory.REMINDER,
        content: `Здравствуйте, {name}! ⚙️

Напоминаем, что вашему {carModel} пора пройти техническое обслуживание.

Запишитесь по телефону или напишите нам!`,
      },
      {
        organizationId,
        name: 'Акция - Скидка 20%',
        category: TemplateCategory.PROMO,
        content: `🔥 СПЕЦИАЛЬНОЕ ПРЕДЛОЖЕНИЕ! 🔥

Здравствуйте, {name}!

Только до конца месяца - скидка 20% на все виды работ!

Не упустите выгодную возможность!`,
      },
      {
        organizationId,
        name: 'День рождения',
        category: TemplateCategory.GREETING,
        content: `🎉 С Днём Рождения, {name}! 🎉

Поздравляем вас с праздником!
Дарим скидку 15% на любые услуги в течение месяца.

Ждём вас!`,
      },
      {
        organizationId,
        name: 'Новые запчасти в наличии',
        category: TemplateCategory.NOTIFICATION,
        content: `📦 Новое поступление!

Здравствуйте, {name}!

В наличии появились запчасти для {carModel}.
Звоните, проконсультируем!`,
      },
    ];

    for (const template of defaultTemplates) {
      await this.templateRepository.save(template);
    }

    return defaultTemplates.length;
  }

  /**
   * Получить все шаблоны организации
   */
  async findAll(organizationId: string) {
    return await this.templateRepository.find({
      where: { organizationId, isActive: true },
      order: { category: 'ASC', usageCount: 'DESC' },
    });
  }

  /**
   * Получить шаблон по ID
   */
  async findOne(id: number, organizationId: string) {
    return await this.templateRepository.findOne({
      where: { id, organizationId },
    });
  }

  /**
   * Создать новый шаблон
   */
  async create(
    organizationId: string,
    data: Partial<MessageTemplate>,
  ) {
    const template = this.templateRepository.create({
      ...data,
      organizationId,
    });
    return await this.templateRepository.save(template);
  }

  /**
   * Обновить шаблон
   */
  async update(
    id: number,
    organizationId: string,
    data: Partial<MessageTemplate>,
  ) {
    await this.templateRepository.update(
      { id, organizationId },
      data,
    );
    return await this.findOne(id, organizationId);
  }

  /**
   * Удалить шаблон (мягкое удаление)
   */
  async remove(id: number, organizationId: string) {
    await this.templateRepository.update(
      { id, organizationId },
      { isActive: false },
    );
    return { success: true };
  }

  /**
   * Увеличить счетчик использования
   */
  async incrementUsage(id: number) {
    await this.templateRepository.increment({ id }, 'usageCount', 1);
  }

  /**
   * Заполнить переменные в шаблоне
   */
  fillTemplate(
    template: string,
    variables: Record<string, string>,
  ): string {
    let result = template;

    for (const [key, value] of Object.entries(variables)) {
      const regex = new RegExp(`\\{${key}\\}`, 'g');
      result = result.replace(regex, value);
    }

    return result;
  }
}

