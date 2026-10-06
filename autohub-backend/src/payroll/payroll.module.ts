import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PayrollController } from './payroll.controller';
import { PayrollService } from './payroll.service';
import { OrderWork } from '../works/entities/order-work.entity';
import { User } from '../users/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([OrderWork, User])],
  controllers: [PayrollController],
  providers: [PayrollService],
})
export class PayrollModule {}
