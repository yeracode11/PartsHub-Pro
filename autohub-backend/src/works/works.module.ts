import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WorksController } from './works.controller';
import { WorksService } from './works.service';
import { WorkCatalog } from './entities/work-catalog.entity';
import { OrderWork } from './entities/order-work.entity';
import { User } from '../users/entities/user.entity';
import { OrganizationsModule } from '../organizations/organizations.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([WorkCatalog, OrderWork, User]),
    OrganizationsModule,
  ],
  controllers: [WorksController],
  providers: [WorksService],
  exports: [WorksService],
})
export class WorksModule {}
