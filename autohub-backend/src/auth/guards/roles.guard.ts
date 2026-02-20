import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '../../common/enums/user-role.enum';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    try {
      const request = context.switchToHttp().getRequest();
      
      const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>('roles', [
        context.getHandler(),
        context.getClass(),
      ]);

      // Если роли не указаны, разрешаем доступ всем авторизованным пользователям
      if (!requiredRoles || requiredRoles.length === 0) {
        return true;
      }

      const { user } = request;
      
      // Проверяем, что пользователь существует
      if (!user) {
        throw new ForbiddenException('User not authenticated');
      }

      // Проверяем, что у пользователя есть роль
      if (!user.role) {
        throw new ForbiddenException('User role not found');
      }

      // Проверяем, есть ли у пользователя одна из требуемых ролей
      const hasRole = requiredRoles.some((role) => user.role === role);
      
      if (!hasRole) {
        throw new ForbiddenException('Insufficient permissions');
      }

      return true;
    } catch (error) {
      // Если это уже ForbiddenException, пробрасываем дальше
      if (error instanceof ForbiddenException) {
        throw error;
      }
      // Для других ошибок логируем и возвращаем 403
      throw new ForbiddenException('Access denied');
    }
  }
}

