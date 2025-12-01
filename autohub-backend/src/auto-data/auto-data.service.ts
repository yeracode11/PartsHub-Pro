import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';

export interface KolesaListItem {
  slug: string;
  name: string;
}

export interface KolesaGeneration {
  id: string;
  name: string;
  year_from: number | null;
  year_to: number | null;
}

@Injectable()
export class AutoDataService {
  private readonly logger = new Logger(AutoDataService.name);
  private readonly client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: 'https://kolesa.kz',
      timeout: 15000, // Увеличиваем таймаут до 15 секунд
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        Accept: 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'X-Requested-With': 'XMLHttpRequest',
        Referer: 'https://kolesa.kz/a/',
        Origin: 'https://kolesa.kz',
      },
      validateStatus: (status) => status < 500, // Не выбрасывать ошибку для 4xx
    });
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private async requestWithRetry<T>(url: string, description: string, retries = 3): Promise<T> {
    let attempt = 0;

    // небольшая задержка перед запросом (200-300 мс)
    await this.sleep(200 + Math.random() * 100);

    while (true) {
      try {
        attempt++;
        this.logger.log(`🌐 [Kolesa] ${description} (attempt ${attempt}) -> ${url}`);

        const res = await this.client.get<T>(url);
        
        // Проверяем, что данные есть
        if (!res.data) {
          throw new Error(`Empty response from Kolesa.kz for ${description}`);
        }

        // Логируем структуру ответа для отладки
        this.logger.debug(`✅ [Kolesa] ${description} response type: ${typeof res.data}, isArray: ${Array.isArray(res.data)}`);
        
        return res.data;
      } catch (error: any) {
        const errorMessage = error.response?.data 
          ? JSON.stringify(error.response.data) 
          : error.message || String(error);
        const statusCode = error.response?.status || 'N/A';
        
        this.logger.warn(
          `⚠️ [Kolesa] Error on ${description} (attempt ${attempt}/${retries}): Status ${statusCode}, ${errorMessage}`,
        );
        
        if (attempt >= retries) {
          this.logger.error(`❌ [Kolesa] Failed ${description} after ${retries} attempts. Last error: ${errorMessage}`);
          throw new Error(`Failed to fetch ${description} from Kolesa.kz after ${retries} attempts: ${errorMessage}`);
        }
        
        await this.sleep(300 + Math.random() * 200);
      }
    }
  }

  async getBrands(): Promise<KolesaListItem[]> {
    try {
      const data = await this.requestWithRetry<any>(
        '/a/ajax-get-list-by-first-letters/?category=cars',
        'get brands',
      );
      
      // Проверяем формат ответа - может быть массив или объект с данными
      if (Array.isArray(data)) {
        this.logger.log(`✅ Got ${data.length} brands (array format)`);
        return data;
      } else if (data && typeof data === 'object') {
        // Если ответ - объект, пытаемся найти массив внутри
        const keys = Object.keys(data);
        this.logger.log(`⚠️ Response is object with keys: ${keys.join(', ')}`);
        
        // Пробуем найти массив в первом уровне объекта
        for (const key of keys) {
          if (Array.isArray(data[key])) {
            this.logger.log(`✅ Found brands array in key: ${key}, length: ${data[key].length}`);
            return data[key];
          }
        }
        
        // Если не нашли массив, возвращаем пустой массив
        this.logger.warn(`⚠️ Could not find brands array in response object`);
        return [];
      } else {
        this.logger.warn(`⚠️ Unexpected response format: ${typeof data}`);
        return [];
      }
    } catch (error: any) {
      this.logger.error(`❌ Error in getBrands: ${error.message}`, error.stack);
      throw error;
    }
  }

  async getModels(brandSlug: string): Promise<KolesaListItem[]> {
    try {
      const data = await this.requestWithRetry<any>(
        `/a/ajax-get-list-by-first-letters/?category=cars&marka=${encodeURIComponent(brandSlug)}`,
        `get models for ${brandSlug}`,
      );
      
      // Проверяем формат ответа
      if (Array.isArray(data)) {
        this.logger.log(`✅ Got ${data.length} models for ${brandSlug} (array format)`);
        return data;
      } else if (data && typeof data === 'object') {
        const keys = Object.keys(data);
        this.logger.log(`⚠️ Response is object with keys: ${keys.join(', ')}`);
        
        for (const key of keys) {
          if (Array.isArray(data[key])) {
            this.logger.log(`✅ Found models array in key: ${key}, length: ${data[key].length}`);
            return data[key];
          }
        }
        
        this.logger.warn(`⚠️ Could not find models array in response object`);
        return [];
      } else {
        this.logger.warn(`⚠️ Unexpected response format: ${typeof data}`);
        return [];
      }
    } catch (error: any) {
      this.logger.error(`❌ Error in getModels for ${brandSlug}: ${error.message}`, error.stack);
      throw error;
    }
  }

  async getGenerations(brandSlug: string, modelSlug: string): Promise<KolesaGeneration[]> {
    try {
      const data = await this.requestWithRetry<any>(
        `/a/ajax-model-generations/?marka=${encodeURIComponent(
          brandSlug,
        )}&model=${encodeURIComponent(modelSlug)}`,
        `get generations for ${brandSlug}/${modelSlug}`,
      );
      
      // Проверяем формат ответа
      if (Array.isArray(data)) {
        this.logger.log(`✅ Got ${data.length} generations for ${brandSlug}/${modelSlug} (array format)`);
        return data;
      } else if (data && typeof data === 'object') {
        const keys = Object.keys(data);
        this.logger.log(`⚠️ Response is object with keys: ${keys.join(', ')}`);
        
        for (const key of keys) {
          if (Array.isArray(data[key])) {
            this.logger.log(`✅ Found generations array in key: ${key}, length: ${data[key].length}`);
            return data[key];
          }
        }
        
        this.logger.warn(`⚠️ Could not find generations array in response object`);
        return [];
      } else {
        this.logger.warn(`⚠️ Unexpected response format: ${typeof data}`);
        return [];
      }
    } catch (error: any) {
      this.logger.error(`❌ Error in getGenerations for ${brandSlug}/${modelSlug}: ${error.message}`, error.stack);
      throw error;
    }
  }
}


