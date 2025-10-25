import { BusinessType } from '../../common/enums/business-type.enum';

export class CreateOrganizationDto {
  name: string;
  businessType: BusinessType;
  phone?: string;
  address?: string;
  settings?: Record<string, any>;
}

