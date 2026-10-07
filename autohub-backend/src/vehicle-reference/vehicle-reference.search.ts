export interface RefName {
  id: number;
  name: string;
  slug: string;
  synonyms: string[];
}

export interface RefGeneration extends RefName {
  yearFrom: number | null;
  yearTo: number | null;
  modelId: number;
}

export interface RefModel extends RefName {
  makeId: number;
  generations: RefGeneration[];
}

export interface RefMake extends RefName {
  models: RefModel[];
}

export interface SearchHit {
  make: Pick<RefName, 'id' | 'name' | 'slug'>;
  model: Pick<RefName, 'id' | 'name' | 'slug'> | null;
  generation: (Pick<RefName, 'id' | 'name' | 'slug'> & {
    yearFrom: number | null;
    yearTo: number | null;
  }) | null;
}

export function normalizeVehicleQuery(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/ё/g, 'е')
    .replace(/\s+/g, ' ');
}

function haystack(row: RefName): string[] {
  return [row.name, row.slug, ...row.synonyms].map(normalizeVehicleQuery);
}

function tokenHits(row: RefName, token: string): boolean {
  const needle = normalizeVehicleQuery(token);
  if (needle.length < 2) return false;
  return haystack(row).some(
    (value) => value === needle || value.includes(needle),
  );
}

/** Детерминированный поиск: имя, slug и синонимы. «camry 70» → Camry XV70. */
export function searchVehicleTree(makes: RefMake[], query: string): SearchHit[] {
  const q = normalizeVehicleQuery(query);
  if (q.length < 2) return [];
  const tokens = q.split(' ').filter((token) => token.length >= 2);
  const hits: SearchHit[] = [];

  for (const make of makes) {
    for (const model of make.models) {
      const modelHit = tokenHits(model, q) || tokens.some((token) => tokenHits(model, token));
      if (!modelHit && !tokenHits(make, q)) continue;
      const generation = model.generations.find((row) =>
        tokens.some((token) => tokenHits(row, token) && !tokenHits(model, token)),
      );
      if (generation) {
        hits.push(toHit(make, model, generation));
        continue;
      }
      if (tokenHits(model, q) || tokens.some((token) => tokenHits(model, token))) {
        hits.push(toHit(make, model, null));
      }
    }
    if (tokenHits(make, q) && !hits.some((hit) => hit.make.id === make.id)) {
      hits.push(toHit(make, null, null));
    }
  }

  return hits.slice(0, 20);
}

function toHit(
  make: RefMake,
  model: RefModel | null,
  generation: RefGeneration | null,
): SearchHit {
  return {
    make: { id: make.id, name: make.name, slug: make.slug },
    model: model ? { id: model.id, name: model.name, slug: model.slug } : null,
    generation: generation
      ? {
          id: generation.id,
          name: generation.name,
          slug: generation.slug,
          yearFrom: generation.yearFrom,
          yearTo: generation.yearTo,
        }
      : null,
  };
}
