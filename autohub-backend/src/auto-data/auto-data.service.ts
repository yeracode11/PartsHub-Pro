import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';

interface KolesaListItem {
  slug: string;
  name: string;
}

interface KolesaGeneration {
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
      timeout: 10000,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        Accept: 'application/json, text/javascript,*/*;q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
      },
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
        return res.data;
      } catch (error: any) {
        this.logger.warn(
          `⚠️ [Kolesa] Error on ${description} (attempt ${attempt}): ${error.message || error}`,
        );
        if (attempt >= retries) {
          this.logger.error(`❌ [Kolesa] Failed ${description} after ${retries} attempts`);
          throw error;
        }
        await this.sleep(300 + Math.random() * 200);
      }
    }
  }

  async getBrands(): Promise<KolesaListItem[]> {
    const data = await this.requestWithRetry<KolesaListItem[]>(
      '/a/ajax-get-list-by-first-letters/?category=cars',
      'get brands',
    );
    return data;
  }

  async getModels(brandSlug: string): Promise<KolesaListItem[]> {
    const data = await this.requestWithRetry<KolesaListItem[]>(
      `/a/ajax-get-list-by-first-letters/?category=cars&marka=${encodeURIComponent(brandSlug)}`,
      `get models for ${brandSlug}`,
    );
    return data;
  }

  async getGenerations(brandSlug: string, modelSlug: string): Promise<KolesaGeneration[]> {
    const data = await this.requestWithRetry<KolesaGeneration[]>(
      `/a/ajax-model-generations/?marka=${encodeURIComponent(
        brandSlug,
      )}&model=${encodeURIComponent(modelSlug)}`,
      `get generations for ${brandSlug}/${modelSlug}`,
    );
    return data;
  }
}


