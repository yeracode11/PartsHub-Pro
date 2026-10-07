import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VehicleMake } from './entities/vehicle-make.entity';
import { VehicleModel } from './entities/vehicle-model.entity';
import { VehicleGeneration } from './entities/vehicle-generation.entity';
import {
  RefMake,
  SearchHit,
  searchVehicleTree,
} from './vehicle-reference.search';
import { slugify } from './vehicle-reference.seed';

const CACHE_MS = 5 * 60 * 1000;

export interface ResolvedVehicle {
  makeId: number;
  modelId: number;
  generationId: number | null;
  make: string;
  model: string;
  generation: string | null;
}

@Injectable()
export class VehicleReferenceService {
  private cache: { at: number; tree: RefMake[] } | null = null;

  constructor(
    @InjectRepository(VehicleMake)
    private readonly makes: Repository<VehicleMake>,
    @InjectRepository(VehicleModel)
    private readonly models: Repository<VehicleModel>,
    @InjectRepository(VehicleGeneration)
    private readonly generations: Repository<VehicleGeneration>,
  ) {}

  async listMakes(search?: string) {
    const tree = await this.tree();
    return tree
      .filter((make) => !search || this.hit(make, search))
      .map((make) => ({ id: make.id, name: make.name, slug: make.slug }));
  }

  async listModels(makeId: number, search?: string) {
    const make = (await this.tree()).find((row) => row.id === makeId);
    if (!make) throw new NotFoundException('Марка не найдена');
    return make.models
      .filter((model) => !search || this.hit(model, search))
      .map((model) => ({ id: model.id, name: model.name, slug: model.slug }));
  }

  async listGenerations(modelId: number, search?: string) {
    const model = (await this.tree())
      .flatMap((make) => make.models)
      .find((row) => row.id === modelId);
    if (!model) throw new NotFoundException('Модель не найдена');
    return model.generations
      .filter((generation) => !search || this.hit(generation, search))
      .map((generation) => ({
        id: generation.id,
        name: generation.name,
        slug: generation.slug,
        yearFrom: generation.yearFrom,
        yearTo: generation.yearTo,
      }));
  }

  async treeSlice(makeId?: number, modelId?: number) {
    const tree = await this.tree();
    if (modelId) {
      for (const make of tree) {
        const model = make.models.find((row) => row.id === modelId);
        if (model) {
          return {
            items: [
              {
                id: make.id,
                name: make.name,
                slug: make.slug,
                models: [
                  {
                    id: model.id,
                    name: model.name,
                    slug: model.slug,
                    generations: model.generations.map((generation) => ({
                      id: generation.id,
                      name: generation.name,
                      slug: generation.slug,
                      yearFrom: generation.yearFrom,
                      yearTo: generation.yearTo,
                    })),
                  },
                ],
              },
            ],
          };
        }
      }
      throw new NotFoundException('Модель не найдена');
    }
    if (makeId) {
      const make = tree.find((row) => row.id === makeId);
      if (!make) throw new NotFoundException('Марка не найдена');
      return {
        items: [
          {
            id: make.id,
            name: make.name,
            slug: make.slug,
            models: make.models.map((model) => ({
              id: model.id,
              name: model.name,
              slug: model.slug,
            })),
          },
        ],
      };
    }
    return {
      items: tree.map((make) => ({ id: make.id, name: make.name, slug: make.slug })),
    };
  }

  async search(query: string): Promise<SearchHit[]> {
    return searchVehicleTree(await this.tree(), query);
  }

  /** Модель обязана принадлежать марке, поколение — модели. */
  async resolveLink(
    makeId: number,
    modelId: number,
    generationId?: number | null,
  ): Promise<ResolvedVehicle> {
    const make = await this.makes.findOne({ where: { id: makeId } });
    const model = await this.models.findOne({ where: { id: modelId } });
    if (!make || !model || model.makeId !== make.id) {
      throw new BadRequestException('Модель не относится к этой марке');
    }
    let generation: VehicleGeneration | null = null;
    if (generationId) {
      generation = await this.generations.findOne({ where: { id: generationId } });
      if (!generation || generation.modelId !== model.id) {
        throw new BadRequestException('Поколение не относится к этой модели');
      }
    }
    return {
      makeId: make.id,
      modelId: model.id,
      generationId: generation?.id ?? null,
      make: make.name,
      model: model.name,
      generation: generation?.name ?? null,
    };
  }

  async matchText(makeName?: string | null, modelName?: string | null, generationName?: string | null) {
    if (!makeName || !modelName) return null;
    const hits = await this.search(`${makeName} ${modelName} ${generationName ?? ''}`.trim());
    const hit =
      hits.find(
        (row) =>
          row.model &&
          row.model.name.toLowerCase() === modelName.trim().toLowerCase() &&
          (!generationName ||
            row.generation?.name.toLowerCase() === generationName.trim().toLowerCase()),
      ) ?? hits.find((row) => row.model);
    if (!hit?.model) return null;
    return {
      makeId: hit.make.id,
      modelId: hit.model.id,
      generationId: hit.generation?.id ?? null,
      make: hit.make.name,
      model: hit.model.name,
      generation: hit.generation?.name ?? generationName ?? null,
    };
  }

  async createMake(name: string, synonyms: string[] = []) {
    const slug = slugify(name);
    const existing = await this.makes.findOne({ where: { slug } });
    if (existing) throw new ConflictException('Такая марка уже есть');
    this.cache = null;
    return this.makes.save(
      this.makes.create({ name: name.trim(), slug, synonyms, isActive: true, sortOrder: 0 }),
    );
  }

  async createModel(makeId: number, name: string, synonyms: string[] = []) {
    const make = await this.makes.findOne({ where: { id: makeId } });
    if (!make) throw new NotFoundException('Марка не найдена');
    const slug = slugify(name);
    const existing = await this.models.findOne({ where: { makeId, slug } });
    if (existing) throw new ConflictException('Такая модель уже есть');
    this.cache = null;
    return this.models.save(
      this.models.create({
        makeId,
        name: name.trim(),
        slug,
        synonyms,
        isActive: true,
        sortOrder: 0,
      }),
    );
  }

  async createGeneration(modelId: number, name: string, synonyms: string[] = []) {
    const model = await this.models.findOne({ where: { id: modelId } });
    if (!model) throw new NotFoundException('Модель не найдена');
    const slug = slugify(name);
    const existing = await this.generations.findOne({ where: { modelId, slug } });
    if (existing) throw new ConflictException('Такое поколение уже есть');
    this.cache = null;
    return this.generations.save(
      this.generations.create({
        modelId,
        name: name.trim(),
        slug,
        synonyms,
        yearFrom: null,
        yearTo: null,
        isActive: true,
        sortOrder: 0,
      }),
    );
  }

  async findMakeBySlug(slug: string) {
    return this.makes.findOne({ where: { slug, isActive: true } });
  }

  async findModelBySlug(makeId: number, slug: string) {
    return this.models.findOne({ where: { makeId, slug, isActive: true } });
  }

  async attachCompatibility<T extends {
    make: string;
    model: string;
    generation: string | null;
    makeId?: number | null;
    modelId?: number | null;
    generationId?: number | null;
  }>(fit: T) {
    if (fit.makeId && fit.modelId) {
      const link = await this.resolveLink(fit.makeId, fit.modelId, fit.generationId);
      return {
        ...fit,
        make: link.make,
        model: link.model,
        generation: link.generation,
        makeId: link.makeId,
        modelId: link.modelId,
        generationId: link.generationId,
      };
    }
    const matched = await this.matchText(fit.make, fit.model, fit.generation);
    if (!matched) return { ...fit, makeId: null, modelId: null, generationId: null };
    return {
      ...fit,
      make: matched.make,
      model: matched.model,
      generation: matched.generationId ? matched.generation : fit.generation,
      makeId: matched.makeId,
      modelId: matched.modelId,
      generationId: matched.generationId,
    };
  }

  private hit(row: { name: string; slug: string; synonyms: string[] }, search: string) {
    const needle = search.trim().toLowerCase();
    if (!needle) return true;
    return [row.name, row.slug, ...row.synonyms].some((value) =>
      value.toLowerCase().includes(needle),
    );
  }

  private async tree(): Promise<RefMake[]> {
    if (this.cache && Date.now() - this.cache.at < CACHE_MS) return this.cache.tree;
    const rows = await this.makes.find({
      where: { isActive: true },
      relations: ['models', 'models.generations'],
      order: { sortOrder: 'ASC', name: 'ASC' },
    });
    const tree: RefMake[] = rows.map((make) => ({
      id: make.id,
      name: make.name,
      slug: make.slug,
      synonyms: make.synonyms ?? [],
      models: (make.models ?? [])
        .filter((model) => model.isActive)
        .sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name))
        .map((model) => ({
          id: model.id,
          makeId: model.makeId,
          name: model.name,
          slug: model.slug,
          synonyms: model.synonyms ?? [],
          generations: (model.generations ?? [])
            .filter((generation) => generation.isActive)
            .sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name))
            .map((generation) => ({
              id: generation.id,
              modelId: generation.modelId,
              name: generation.name,
              slug: generation.slug,
              synonyms: generation.synonyms ?? [],
              yearFrom: generation.yearFrom,
              yearTo: generation.yearTo,
            })),
        })),
    }));
    this.cache = { at: Date.now(), tree };
    return tree;
  }
}
