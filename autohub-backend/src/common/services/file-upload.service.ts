import { Injectable } from '@nestjs/common';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class FileUploadService {
  // Настройка multer для загрузки файлов
  static getMulterConfig() {
    return {
      storage: diskStorage({
        destination: join(process.cwd(), 'uploads', 'items'),
        filename: (req, file, callback) => {
          const uniqueSuffix = uuidv4();
          const ext = extname(file.originalname);
          const filename = `${uniqueSuffix}${ext}`;
          callback(null, filename);
        },
      }),
      fileFilter: (req, file, callback) => {
        // Разрешаем только изображения
        if (file.mimetype.match(/\/(jpg|jpeg|png|gif|webp)$/)) {
          callback(null, true);
        } else {
          callback(new Error('Only image files are allowed!'), false);
        }
      },
      limits: {
        fileSize: 5 * 1024 * 1024, // 5MB максимум
      },
    };
  }

  // Генерация URL для загруженного файла
  static generateFileUrl(filename: string): string {
    return `/uploads/items/${filename}`;
  }

  // Получение полного пути к файлу
  static getFilePath(filename: string): string {
    return `./uploads/items/${filename}`;
  }
}
