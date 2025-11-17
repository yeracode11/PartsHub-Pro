import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { IncomingService } from './incoming.service';
import { IncomingController } from './incoming.controller';
import { IncomingDoc } from './entities/incoming-doc.entity';
import { IncomingItem } from './entities/incoming-item.entity';
import { Item } from '../items/entities/item.entity';
import { OrganizationsModule } from '../organizations/organizations.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([IncomingDoc, IncomingItem, Item]),
    OrganizationsModule,
  ],
  controllers: [IncomingController],
  providers: [IncomingService],
  exports: [IncomingService],
})
export class IncomingModule {}

