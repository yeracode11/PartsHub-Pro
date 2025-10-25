import { UserRole } from '../../common/enums/user-role.enum';

export class CreateUserDto {
  firebaseUid: string; // ID из Firebase Auth
  email: string;
  name: string;
  role: UserRole;
  organizationId: string;
}

