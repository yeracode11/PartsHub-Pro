import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpStatus,
  HttpException,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';

/**
 * Фильтр для эндпоинтов WhatsApp: вместо 500 возвращаем 200 с success: false.
 * 401/403 не перехватываем — оставляем для авторизации.
 */
@Catch()
export class WhatsAppExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(WhatsAppExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest();
    const url = request?.url || request?.path || '';

    // Только для WhatsApp API
    if (!url.includes('/api/whatsapp')) {
      throw exception;
    }

    // 401/403 не перехватываем — пусть Nest обработает как обычно
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      if (status === HttpStatus.UNAUTHORIZED || status === HttpStatus.FORBIDDEN) {
        throw exception;
      }
    }

    const message =
      exception instanceof Error ? exception.message : String(exception);
    const stack = exception instanceof Error ? exception.stack : undefined;

    this.logger.error(
      `WhatsApp error [${request.method} ${url}]: ${message}`,
      stack,
    );

    response.status(HttpStatus.OK).json({
      success: false,
      message: message || 'Внутренняя ошибка',
      qrCode: null,
    });
  }
}
