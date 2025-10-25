import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { B2CController } from './b2c.controller';
import { ItemsService } from '../items/items.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { Item } from '../items/entities/item.entity';
import { Organization } from '../organizations/entities/organization.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Item, Organization]),
  ],
  controllers: [B2CController],
  providers: [ItemsService, OrganizationsService],
  exports: [ItemsService, OrganizationsService],
})
export class B2CModule {}
