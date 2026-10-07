export interface SeedGeneration {
  name: string;
  yearFrom?: number;
  yearTo?: number | null;
  synonyms?: string[];
}

export interface SeedModel {
  name: string;
  synonyms?: string[];
  generations?: SeedGeneration[];
}

export interface SeedMake {
  name: string;
  synonyms?: string[];
  models: SeedModel[];
}

export function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Базовый справочник. Поколения только там, где обозначение общепринято. */
export const VEHICLE_SEED: SeedMake[] = [
  {
    name: 'Toyota',
    synonyms: ['Тойота', 'Тоета'],
    models: [
      {
        name: 'Camry',
        synonyms: ['Камри', 'Кэмри', 'Toyota Camry'],
        generations: [
          { name: 'XV30', yearFrom: 2001, yearTo: 2006 },
          { name: 'XV40', yearFrom: 2006, yearTo: 2011 },
          { name: 'XV50', yearFrom: 2011, yearTo: 2017 },
          { name: 'XV70', yearFrom: 2017, yearTo: 2021, synonyms: ['70', 'XV 70'] },
          { name: 'XV80', yearFrom: 2021, yearTo: null, synonyms: ['80', 'XV 80'] },
        ],
      },
      { name: 'Corolla', synonyms: ['Королла'] },
      {
        name: 'Land Cruiser',
        synonyms: ['Ленд Крузер', 'Лэнд Крузер', 'Крузак', 'Land Cruiser 100'],
        generations: [
          { name: '80', yearFrom: 1990, yearTo: 1997, synonyms: ['J80'] },
          { name: '100', yearFrom: 1998, yearTo: 2007, synonyms: ['J100'] },
          { name: '200', yearFrom: 2007, yearTo: 2021, synonyms: ['J200'] },
          { name: '300', yearFrom: 2021, yearTo: null, synonyms: ['J300'] },
        ],
      },
      {
        name: 'Land Cruiser Prado',
        synonyms: ['Прадо', 'Prado', 'Ленд Крузер Прадо'],
        generations: [
          { name: '90', yearFrom: 1996, yearTo: 2002 },
          { name: '120', yearFrom: 2002, yearTo: 2009 },
          { name: '150', yearFrom: 2009, yearTo: 2023 },
          { name: '250', yearFrom: 2023, yearTo: null },
        ],
      },
      {
        name: 'RAV4',
        synonyms: ['Рав4', 'Рав 4'],
        generations: [
          { name: 'XA30', yearFrom: 2005, yearTo: 2012 },
          { name: 'XA40', yearFrom: 2012, yearTo: 2018 },
          { name: 'XA50', yearFrom: 2018, yearTo: null },
        ],
      },
      { name: 'Highlander', synonyms: ['Хайлендер'] },
      { name: 'Crown', synonyms: ['Краун'] },
      { name: 'Avalon', synonyms: ['Авалон'] },
      { name: 'Prius', synonyms: ['Приус'] },
      { name: 'Hilux', synonyms: ['Хайлюкс'] },
    ],
  },
  {
    name: 'Lexus',
    synonyms: ['Лексус'],
    models: [
      { name: 'RX', synonyms: ['Лексус RX'] },
      {
        name: 'LX',
        synonyms: ['Лексус LX'],
        generations: [
          { name: '470', yearFrom: 1998, yearTo: 2007 },
          { name: '570', yearFrom: 2007, yearTo: 2021 },
          { name: '600', yearFrom: 2021, yearTo: null },
        ],
      },
      { name: 'ES' },
      { name: 'IS' },
      { name: 'GX' },
      { name: 'NX' },
    ],
  },
  {
    name: 'Mercedes-Benz',
    synonyms: ['Mercedes', 'Мерседес', 'Мерседес-Бенц'],
    models: [
      {
        name: 'C-Class',
        synonyms: ['C класс', 'Цешка', 'W205'],
        generations: [
          { name: 'W202', yearFrom: 1993, yearTo: 2000 },
          { name: 'W203', yearFrom: 2000, yearTo: 2007 },
          { name: 'W204', yearFrom: 2007, yearTo: 2014 },
          { name: 'W205', yearFrom: 2014, yearTo: 2021 },
          { name: 'W206', yearFrom: 2021, yearTo: null },
        ],
      },
      {
        name: 'E-Class',
        synonyms: ['E класс', 'Ешка'],
        generations: [
          { name: 'W210', yearFrom: 1995, yearTo: 2002 },
          { name: 'W211', yearFrom: 2002, yearTo: 2009 },
          { name: 'W212', yearFrom: 2009, yearTo: 2016 },
          { name: 'W213', yearFrom: 2016, yearTo: 2023 },
          { name: 'W214', yearFrom: 2023, yearTo: null },
        ],
      },
      {
        name: 'S-Class',
        synonyms: ['S класс'],
        generations: [
          { name: 'W220', yearFrom: 1998, yearTo: 2005 },
          { name: 'W221', yearFrom: 2005, yearTo: 2013 },
          { name: 'W222', yearFrom: 2013, yearTo: 2020 },
          { name: 'W223', yearFrom: 2020, yearTo: null },
        ],
      },
      { name: 'GLC', synonyms: ['ГЛЦ'] },
      { name: 'GLE', synonyms: ['ГЛЕ'] },
      { name: 'GLS', synonyms: ['ГЛС'] },
    ],
  },
  {
    name: 'BMW',
    synonyms: ['БМВ'],
    models: [
      {
        name: '3 Series',
        synonyms: ['3 серия', 'Тройка', 'BMW 3'],
        generations: [
          { name: 'E30', yearFrom: 1982, yearTo: 1994 },
          { name: 'E36', yearFrom: 1990, yearTo: 2000 },
          { name: 'E46', yearFrom: 1998, yearTo: 2006 },
          { name: 'E90', yearFrom: 2005, yearTo: 2013, synonyms: ['E91', 'E92'] },
          { name: 'F30', yearFrom: 2011, yearTo: 2019 },
          { name: 'G20', yearFrom: 2018, yearTo: null },
        ],
      },
      {
        name: '5 Series',
        synonyms: ['5 серия', 'Пятёрка', 'BMW 5'],
        generations: [
          { name: 'E34', yearFrom: 1988, yearTo: 1996 },
          { name: 'E39', yearFrom: 1995, yearTo: 2003 },
          { name: 'E60', yearFrom: 2003, yearTo: 2010 },
          { name: 'F10', yearFrom: 2010, yearTo: 2017 },
          { name: 'G30', yearFrom: 2017, yearTo: null },
        ],
      },
      {
        name: '7 Series',
        synonyms: ['7 серия', 'BMW 7'],
        generations: [
          { name: 'E38', yearFrom: 1994, yearTo: 2001 },
          { name: 'E65', yearFrom: 2001, yearTo: 2008 },
          { name: 'F01', yearFrom: 2008, yearTo: 2015 },
          { name: 'G11', yearFrom: 2015, yearTo: null },
        ],
      },
      {
        name: 'X3',
        generations: [
          { name: 'E83', yearFrom: 2003, yearTo: 2010 },
          { name: 'F25', yearFrom: 2010, yearTo: 2017 },
          { name: 'G01', yearFrom: 2017, yearTo: null },
        ],
      },
      {
        name: 'X5',
        synonyms: ['Х5'],
        generations: [
          { name: 'E53', yearFrom: 1999, yearTo: 2006 },
          { name: 'E70', yearFrom: 2006, yearTo: 2013 },
          { name: 'F15', yearFrom: 2013, yearTo: 2018 },
          { name: 'G05', yearFrom: 2018, yearTo: null },
        ],
      },
      {
        name: 'X6',
        synonyms: ['Х6'],
        generations: [
          { name: 'E71', yearFrom: 2008, yearTo: 2014 },
          { name: 'F16', yearFrom: 2014, yearTo: 2019 },
          { name: 'G06', yearFrom: 2019, yearTo: null },
        ],
      },
    ],
  },
  {
    name: 'Audi',
    synonyms: ['Ауди'],
    models: [
      {
        name: 'A4',
        generations: [
          { name: 'B6', yearFrom: 2000, yearTo: 2004 },
          { name: 'B7', yearFrom: 2004, yearTo: 2008 },
          { name: 'B8', yearFrom: 2007, yearTo: 2015 },
          { name: 'B9', yearFrom: 2015, yearTo: null },
        ],
      },
      {
        name: 'A6',
        generations: [
          { name: 'C5', yearFrom: 1997, yearTo: 2004 },
          { name: 'C6', yearFrom: 2004, yearTo: 2011 },
          { name: 'C7', yearFrom: 2011, yearTo: 2018 },
          { name: 'C8', yearFrom: 2018, yearTo: null },
        ],
      },
      { name: 'Q5' },
      { name: 'Q7' },
    ],
  },
  {
    name: 'Volkswagen',
    synonyms: ['VW', 'Фольксваген', 'Фольцваген'],
    models: [
      {
        name: 'Golf',
        synonyms: ['Гольф'],
        generations: [
          { name: 'Mk5', yearFrom: 2003, yearTo: 2008 },
          { name: 'Mk6', yearFrom: 2008, yearTo: 2012 },
          { name: 'Mk7', yearFrom: 2012, yearTo: 2019 },
          { name: 'Mk8', yearFrom: 2019, yearTo: null },
        ],
      },
      {
        name: 'Passat',
        synonyms: ['Пассат'],
        generations: [
          { name: 'B6', yearFrom: 2005, yearTo: 2010 },
          { name: 'B7', yearFrom: 2010, yearTo: 2015 },
          { name: 'B8', yearFrom: 2014, yearTo: null },
        ],
      },
      { name: 'Polo', synonyms: ['Поло'] },
      { name: 'Tiguan', synonyms: ['Тигуан'] },
    ],
  },
  {
    name: 'Hyundai',
    synonyms: ['Хендай', 'Хундай', 'Хёндай'],
    models: [
      { name: 'Accent', synonyms: ['Акцент'] },
      { name: 'Elantra', synonyms: ['Элантра'] },
      { name: 'Sonata', synonyms: ['Соната'] },
      { name: 'Tucson', synonyms: ['Туссан', 'Туксон'] },
      { name: 'Santa Fe', synonyms: ['Санта Фе'] },
      { name: 'Palisade', synonyms: ['Палисад'] },
    ],
  },
  {
    name: 'Kia',
    synonyms: ['Киа'],
    models: [
      { name: 'Rio', synonyms: ['Рио'] },
      { name: 'Cerato', synonyms: ['Церато'] },
      { name: 'K5', synonyms: ['Оптима', 'Optima'] },
      { name: 'Sportage', synonyms: ['Спортейдж'] },
      { name: 'Sorento', synonyms: ['Соренто'] },
      { name: 'Carnival', synonyms: ['Карнивал'] },
    ],
  },
  {
    name: 'Nissan',
    synonyms: ['Ниссан'],
    models: [
      {
        name: 'X-Trail',
        synonyms: ['Икс Трейл', 'Xtrail'],
        generations: [
          { name: 'T31', yearFrom: 2007, yearTo: 2013 },
          { name: 'T32', yearFrom: 2013, yearTo: 2021 },
          { name: 'T33', yearFrom: 2021, yearTo: null },
        ],
      },
      { name: 'Qashqai', synonyms: ['Кашкай'] },
      {
        name: 'Patrol',
        synonyms: ['Патрол'],
        generations: [
          { name: 'Y61', yearFrom: 1997, yearTo: 2010 },
          { name: 'Y62', yearFrom: 2010, yearTo: null },
        ],
      },
      { name: 'Teana', synonyms: ['Теана'] },
      { name: 'Almera', synonyms: ['Альмера'] },
    ],
  },
  {
    name: 'Mitsubishi',
    synonyms: ['Митсубиси', 'Митсубиши'],
    models: [
      { name: 'Pajero', synonyms: ['Паджеро'] },
      { name: 'Lancer', synonyms: ['Лансер'] },
      { name: 'Outlander', synonyms: ['Аутлендер'] },
      { name: 'L200', synonyms: ['Л200'] },
    ],
  },
  {
    name: 'Honda',
    synonyms: ['Хонда'],
    models: [
      { name: 'Accord', synonyms: ['Аккорд'] },
      { name: 'Civic', synonyms: ['Цивик'] },
      { name: 'CR-V', synonyms: ['ЦРВ', 'CRV'] },
      { name: 'Fit', synonyms: ['Фит'] },
    ],
  },
  {
    name: 'Mazda',
    synonyms: ['Мазда'],
    models: [
      { name: '3', synonyms: ['Мазда 3'] },
      { name: '6', synonyms: ['Мазда 6'] },
      {
        name: 'CX-5',
        synonyms: ['CX5'],
        generations: [
          { name: 'KE', yearFrom: 2012, yearTo: 2017 },
          { name: 'KF', yearFrom: 2017, yearTo: null },
        ],
      },
      { name: 'CX-9' },
    ],
  },
  {
    name: 'Subaru',
    synonyms: ['Субару'],
    models: [
      {
        name: 'Forester',
        synonyms: ['Форестер'],
        generations: [
          { name: 'SG', yearFrom: 2002, yearTo: 2008 },
          { name: 'SH', yearFrom: 2008, yearTo: 2012 },
          { name: 'SJ', yearFrom: 2012, yearTo: 2018 },
          { name: 'SK', yearFrom: 2018, yearTo: null },
        ],
      },
      { name: 'Outback', synonyms: ['Аутбек'] },
      { name: 'Legacy', synonyms: ['Легаси'] },
      { name: 'XV', synonyms: ['ХВ'] },
    ],
  },
  {
    name: 'Chevrolet',
    synonyms: ['Шевроле'],
    models: [
      { name: 'Cobalt', synonyms: ['Кобальт'] },
      { name: 'Cruze', synonyms: ['Круз'] },
      { name: 'Malibu', synonyms: ['Малибу'] },
      { name: 'Tahoe', synonyms: ['Тахо'] },
      { name: 'Captiva', synonyms: ['Каптива'] },
    ],
  },
  {
    name: 'Daewoo',
    synonyms: ['Дэу', 'Деу'],
    models: [
      { name: 'Nexia', synonyms: ['Нексия'] },
      { name: 'Matiz', synonyms: ['Матиз'] },
      { name: 'Gentra', synonyms: ['Гентра'] },
      { name: 'Lacetti', synonyms: ['Лачетти'] },
    ],
  },
  {
    name: 'Ford',
    synonyms: ['Форд'],
    models: [
      {
        name: 'Focus',
        synonyms: ['Фокус'],
        generations: [
          { name: 'Mk2', yearFrom: 2004, yearTo: 2011 },
          { name: 'Mk3', yearFrom: 2011, yearTo: 2018 },
          { name: 'Mk4', yearFrom: 2018, yearTo: null },
        ],
      },
      { name: 'Mondeo', synonyms: ['Мондео'] },
      { name: 'Explorer', synonyms: ['Эксплорер'] },
      { name: 'Ranger', synonyms: ['Рейнджер'] },
    ],
  },
  {
    name: 'Land Rover',
    synonyms: ['Ленд Ровер', 'Рендж Ровер'],
    models: [
      {
        name: 'Range Rover',
        synonyms: ['Рендж Ровер'],
        generations: [
          { name: 'L322', yearFrom: 2002, yearTo: 2012 },
          { name: 'L405', yearFrom: 2012, yearTo: 2021 },
          { name: 'L460', yearFrom: 2021, yearTo: null },
        ],
      },
      { name: 'Range Rover Sport', synonyms: ['Рендж Ровер Спорт'] },
      { name: 'Discovery', synonyms: ['Дискавери'] },
      {
        name: 'Defender',
        synonyms: ['Дефендер'],
        generations: [
          { name: 'L316', yearFrom: 1990, yearTo: 2016 },
          { name: 'L663', yearFrom: 2019, yearTo: null },
        ],
      },
    ],
  },
  {
    name: 'Porsche',
    synonyms: ['Порше'],
    models: [
      {
        name: 'Cayenne',
        synonyms: ['Кайен'],
        generations: [
          { name: '955', yearFrom: 2002, yearTo: 2007 },
          { name: '957', yearFrom: 2007, yearTo: 2010 },
          { name: '958', yearFrom: 2010, yearTo: 2017 },
          { name: 'E3', yearFrom: 2017, yearTo: null },
        ],
      },
      { name: 'Macan', synonyms: ['Макан'] },
      { name: 'Panamera', synonyms: ['Панамера'] },
    ],
  },
  {
    name: 'Volvo',
    synonyms: ['Вольво'],
    models: [
      { name: 'XC90' },
      { name: 'XC60' },
      { name: 'S60' },
      { name: 'S90' },
    ],
  },
  {
    name: 'Skoda',
    synonyms: ['Шкода'],
    models: [
      {
        name: 'Octavia',
        synonyms: ['Октавия'],
        generations: [
          { name: 'A5', yearFrom: 2004, yearTo: 2013 },
          { name: 'A7', yearFrom: 2013, yearTo: 2020 },
          { name: 'A8', yearFrom: 2020, yearTo: null },
        ],
      },
      { name: 'Superb', synonyms: ['Суперб'] },
      { name: 'Kodiaq', synonyms: ['Кодиак'] },
      { name: 'Rapid', synonyms: ['Рапид'] },
    ],
  },
  {
    name: 'Chery',
    synonyms: ['Чери'],
    models: [
      { name: 'Tiggo 4', synonyms: ['Тигго 4'] },
      { name: 'Tiggo 7', synonyms: ['Тигго 7'] },
      { name: 'Tiggo 8', synonyms: ['Тигго 8'] },
      { name: 'Arrizo', synonyms: ['Арризо'] },
    ],
  },
  {
    name: 'Geely',
    synonyms: ['Джили', 'Джилли'],
    models: [
      { name: 'Coolray', synonyms: ['Кулрей'] },
      { name: 'Atlas', synonyms: ['Атлас'] },
      { name: 'Monjaro', synonyms: ['Монжаро'] },
      { name: 'Emgrand', synonyms: ['Эмгранд'] },
    ],
  },
  {
    name: 'Haval',
    synonyms: ['Хавал', 'Хавейл'],
    models: [
      { name: 'Jolion', synonyms: ['Джолион'] },
      { name: 'F7' },
      { name: 'H9' },
      { name: 'Dargo', synonyms: ['Дарго'] },
    ],
  },
  {
    name: 'Jetour',
    synonyms: ['Джетур', 'Джитур'],
    models: [
      { name: 'Dashing', synonyms: ['Дашинг'] },
      { name: 'X70' },
      { name: 'T2' },
    ],
  },
  {
    name: 'Changan',
    synonyms: ['Чанган'],
    models: [
      { name: 'CS35' },
      { name: 'CS55' },
      { name: 'CS75' },
      { name: 'UNI-K' },
    ],
  },
  {
    name: 'Li Auto',
    synonyms: ['Лисян', 'Lixiang'],
    models: [{ name: 'L7' }, { name: 'L9' }],
  },
  {
    name: 'Zeekr',
    synonyms: ['Зикр'],
    models: [{ name: '001' }, { name: '007' }, { name: 'X' }],
  },
  {
    name: 'BYD',
    synonyms: ['БИД'],
    models: [
      { name: 'Song', synonyms: ['Сонг'] },
      { name: 'Seal', synonyms: ['Сил'] },
      { name: 'Han', synonyms: ['Хан'] },
      { name: 'Tang', synonyms: ['Танг'] },
    ],
  },
];
