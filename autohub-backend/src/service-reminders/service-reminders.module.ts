import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Vehicle } from '../vehicles/entities/vehicle.entity';
import { WhatsAppConnection } from '../whatsapp/entities/whatsapp-connection.entity';
import { WhatsAppModule } from '../whatsapp/whatsapp.module';
import { ServiceReminderSettings } from './entities/service-reminder-settings.entity';
import { ServiceReminderLog } from './entities/service-reminder-log.entity';
import { ServiceRemindersController } from './service-reminders.controller';
import { ServiceRemindersService } from './service-reminders.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ServiceReminderSettings,
      ServiceReminderLog,
      Vehicle,
      WhatsAppConnection,
    ]),
    WhatsAppModule,
  ],
  controllers: [ServiceRemindersController],
  providers: [ServiceRemindersService],
})
export class ServiceRemindersModule {}
