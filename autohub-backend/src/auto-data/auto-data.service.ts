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
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        Accept: 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'X-Requested-With': 'XMLHttpRequest',
        Referer: 'https://kolesa.kz/a/new/',
        Origin: 'https://kolesa.kz',
        'Cache-Control': 'no-cache',
        Pragma: 'no-cache',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
      },
      maxRedirects: 5,
      validateStatus: (status) => status >= 200 && status < 400,
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

        const res = await this.client.get(url, {
          responseType: 'text', // Сначала получаем как текст, чтобы проверить на HTML
        });
        
        // Проверяем, что данные есть
        if (!res.data) {
          throw new Error(`Empty response from Kolesa.kz for ${description}`);
        }

        // Проверяем Content-Type
        const contentType = res.headers['content-type'] || '';
        this.logger.debug(`📋 [Kolesa] ${description} Content-Type: ${contentType}`);

        // Проверяем, что это не HTML
        const dataStr = typeof res.data === 'string' ? res.data : JSON.stringify(res.data);
        const trimmed = dataStr.trim();
        
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html') || trimmed.startsWith('<!')) {
          this.logger.error(`❌ [Kolesa] Received HTML instead of JSON for ${description}`);
          this.logger.error(`📄 First 500 chars of response: ${trimmed.substring(0, 500)}`);
          throw new Error(`Kolesa.kz returned HTML instead of JSON. The endpoint may have changed or requires authentication.`);
        }

        // Пытаемся распарсить как JSON
        let parsedData: any;
        try {
          parsedData = JSON.parse(dataStr);
        } catch (parseError) {
          this.logger.error(`❌ [Kolesa] Failed to parse JSON for ${description}: ${parseError}`);
          this.logger.error(`📄 First 500 chars of response: ${trimmed.substring(0, 500)}`);
          throw new Error(`Failed to parse Kolesa.kz response as JSON: ${parseError}`);
        }

        // Логируем структуру ответа для отладки
        this.logger.debug(`✅ [Kolesa] ${description} response type: ${typeof parsedData}, isArray: ${Array.isArray(parsedData)}`);
        
        return parsedData as T;
      } catch (error: any) {
        const statusCode = error.response?.status || 'N/A';
        let errorMessage = error.message || String(error);
        
        // Если получили HTML, пытаемся извлечь полезную информацию
        if (error.response?.data && typeof error.response.data === 'string') {
          const htmlData = error.response.data.substring(0, 200); // Первые 200 символов
          if (htmlData.includes('<!DOCTYPE') || htmlData.includes('<html')) {
            errorMessage = `Kolesa.kz returned HTML (status ${statusCode}). The endpoint may have changed.`;
          } else {
            errorMessage = error.response.data.substring(0, 500);
          }
        } else if (error.response?.data) {
          errorMessage = JSON.stringify(error.response.data).substring(0, 500);
        }
        
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
    // Пробуем несколько вариантов эндпоинтов
    const endpoints = [
      '/a/ajax-get-list-by-first-letters/?category=cars',
      '/a/ajax-get-list-by-first-letters/?category=cars&_=' + Date.now(),
      '/cars/ajax-get-list-by-first-letters/?category=cars',
    ];

    for (const endpoint of endpoints) {
      try {
        this.logger.log(`🔄 Trying endpoint: ${endpoint}`);
        const data = await this.requestWithRetry<any>(endpoint, 'get brands');
        
        const result = this.extractBrandsArray(data);
        if (result.length > 0) {
          this.logger.log(`✅ Successfully got ${result.length} brands from ${endpoint}`);
          return result;
        }
      } catch (error: any) {
        this.logger.warn(`⚠️ Endpoint ${endpoint} failed: ${error.message}`);
        // Продолжаем пробовать следующий эндпоинт
        continue;
      }
    }

    // Если все эндпоинты не сработали, возвращаем пустой массив
    this.logger.error(`❌ All endpoints failed. Kolesa.kz API may have changed.`);
    throw new Error('Failed to fetch brands from Kolesa.kz. The API endpoints may have changed.');
  }

  private extractBrandsArray(data: any): KolesaListItem[] {
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

  // Статический список популярных марок автомобилей
  getStaticBrands(): KolesaListItem[] {
    return [
      { slug: 'toyota', name: 'Toyota' },
      { slug: 'lexus', name: 'Lexus' },
      { slug: 'bmw', name: 'BMW' },
      { slug: 'mercedes-benz', name: 'Mercedes-Benz' },
      { slug: 'audi', name: 'Audi' },
      { slug: 'volkswagen', name: 'Volkswagen' },
      { slug: 'hyundai', name: 'Hyundai' },
      { slug: 'kia', name: 'Kia' },
      { slug: 'nissan', name: 'Nissan' },
      { slug: 'mazda', name: 'Mazda' },
      { slug: 'honda', name: 'Honda' },
      { slug: 'ford', name: 'Ford' },
      { slug: 'chevrolet', name: 'Chevrolet' },
      { slug: 'skoda', name: 'Škoda' },
      { slug: 'renault', name: 'Renault' },
      { slug: 'peugeot', name: 'Peugeot' },
      { slug: 'citroen', name: 'Citroën' },
      { slug: 'opel', name: 'Opel' },
      { slug: 'volvo', name: 'Volvo' },
      { slug: 'subaru', name: 'Subaru' },
      { slug: 'mitsubishi', name: 'Mitsubishi' },
      { slug: 'suzuki', name: 'Suzuki' },
      { slug: 'geely', name: 'Geely' },
      { slug: 'haval', name: 'Haval' },
      { slug: 'chery', name: 'Chery' },
      { slug: 'lada', name: 'Lada' },
      { slug: 'uaz', name: 'UAZ' },
      { slug: 'gaz', name: 'GAZ' },
    ];
  }

  // Статический список моделей для популярных марок
  getStaticModels(brandSlug: string): KolesaListItem[] {
    const modelsMap: Record<string, KolesaListItem[]> = {
      toyota: [
        { slug: 'camry', name: 'Camry' },
        { slug: 'corolla', name: 'Corolla' },
        { slug: 'rav4', name: 'RAV4' },
        { slug: 'land-cruiser', name: 'Land Cruiser' },
        { slug: 'prado', name: 'Prado' },
        { slug: 'highlander', name: 'Highlander' },
        { slug: 'hilux', name: 'Hilux' },
        { slug: 'prius', name: 'Prius' },
      ],
      lexus: [
        { slug: 'rx', name: 'RX' },
        { slug: 'lx', name: 'LX' },
        { slug: 'es', name: 'ES' },
        { slug: 'nx', name: 'NX' },
        { slug: 'gx', name: 'GX' },
      ],
      bmw: [
        { slug: '3-series', name: '3 Series' },
        { slug: '5-series', name: '5 Series' },
        { slug: '7-series', name: '7 Series' },
        { slug: 'x3', name: 'X3' },
        { slug: 'x5', name: 'X5' },
        { slug: 'x7', name: 'X7' },
      ],
      'mercedes-benz': [
        { slug: 'c-class', name: 'C-Class' },
        { slug: 'e-class', name: 'E-Class' },
        { slug: 's-class', name: 'S-Class' },
        { slug: 'gle', name: 'GLE' },
        { slug: 'gls', name: 'GLS' },
        { slug: 'g-class', name: 'G-Class' },
      ],
      audi: [
        { slug: 'a4', name: 'A4' },
        { slug: 'a6', name: 'A6' },
        { slug: 'a8', name: 'A8' },
        { slug: 'q5', name: 'Q5' },
        { slug: 'q7', name: 'Q7' },
        { slug: 'q8', name: 'Q8' },
      ],
      volkswagen: [
        { slug: 'polo', name: 'Polo' },
        { slug: 'jetta', name: 'Jetta' },
        { slug: 'passat', name: 'Passat' },
        { slug: 'tiguan', name: 'Tiguan' },
        { slug: 'touareg', name: 'Touareg' },
      ],
      hyundai: [
        { slug: 'solaris', name: 'Solaris' },
        { slug: 'elantra', name: 'Elantra' },
        { slug: 'sonata', name: 'Sonata' },
        { slug: 'santa-fe', name: 'Santa Fe' },
        { slug: 'tucson', name: 'Tucson' },
        { slug: 'palisade', name: 'Palisade' },
      ],
      kia: [
        { slug: 'rio', name: 'Rio' },
        { slug: 'cerato', name: 'Cerato' },
        { slug: 'optima', name: 'Optima' },
        { slug: 'sportage', name: 'Sportage' },
        { slug: 'sorento', name: 'Sorento' },
      ],
      nissan: [
        { slug: 'almera', name: 'Almera' },
        { slug: 'sentra', name: 'Sentra' },
        { slug: 'altima', name: 'Altima' },
        { slug: 'x-trail', name: 'X-Trail' },
        { slug: 'patrol', name: 'Patrol' },
        { slug: 'qashqai', name: 'Qashqai' },
      ],
    };

    return modelsMap[brandSlug.toLowerCase()] || [];
  }
}


