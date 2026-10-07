import { searchVehicleTree, RefMake } from './vehicle-reference.search';

const tree: RefMake[] = [
  {
    id: 1,
    name: 'Toyota',
    slug: 'toyota',
    synonyms: ['Тойота'],
    models: [
      {
        id: 10,
        makeId: 1,
        name: 'Camry',
        slug: 'camry',
        synonyms: ['Камри', 'Кэмри', 'Toyota Camry'],
        generations: [
          {
            id: 100,
            modelId: 10,
            name: 'XV70',
            slug: 'xv70',
            synonyms: ['70'],
            yearFrom: 2017,
            yearTo: 2021,
          },
        ],
      },
    ],
  },
  {
    id: 2,
    name: 'BMW',
    slug: 'bmw',
    synonyms: ['БМВ'],
    models: [
      {
        id: 20,
        makeId: 2,
        name: 'X5',
        slug: 'x5',
        synonyms: [],
        generations: [],
      },
    ],
  },
];

describe('поиск справочника', () => {
  it('находит Camry по латинскому и русскому написанию', () => {
    for (const query of ['Camry', 'Камри', 'Кэмри', 'camry', 'toyota camry']) {
      const [hit] = searchVehicleTree(tree, query);
      expect(hit.make.name).toBe('Toyota');
      expect(hit.model?.name).toBe('Camry');
    }
  });

  it('camry 70 находит поколение XV70 и не путает с другой маркой', () => {
    for (const query of ['camry 70', 'камри 70', 'camry xv70']) {
      const [hit] = searchVehicleTree(tree, query);
      expect(hit.generation?.name).toBe('XV70');
      expect(hit.make.name).toBe('Toyota');
    }
  });
});
