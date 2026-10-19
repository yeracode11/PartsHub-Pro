import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateVehicleDto, UpdateVehicleDto } from './vehicle.dto';

const valid = {
  customerId: 1,
  brand: 'Toyota',
  model: 'Camry',
  year: 2018,
  plateNumber: '001ABC02',
};

const errorsOf = async (cls: any, plain: object) =>
  (await validate(plainToInstance(cls, plain), { whitelist: true })).map(
    (e) => e.property,
  );

describe('vehicle DTO', () => {
  it('accepts the payload the app sends (null optionals included)', async () => {
    expect(
      await errorsOf(CreateVehicleDto, {
        ...valid,
        color: null,
        vin: null,
        fuelType: 'petrol',
        transmission: 'manual',
        engineVolume: null,
        enginePower: null,
        currentMileage: 0,
        notes: null,
      }),
    ).toEqual([]);
  });

  it('rejects wrong types, unknown enums and negative mileage', async () => {
    const errors = await errorsOf(CreateVehicleDto, {
      ...valid,
      year: 'abc',
      fuelType: 'steam',
      currentMileage: -5,
    });
    expect(errors.sort()).toEqual(['currentMileage', 'fuelType', 'year']);
  });

  it('requires owner, brand, model and plate on create', async () => {
    expect((await errorsOf(CreateVehicleDto, {})).sort()).toEqual([
      'brand',
      'customerId',
      'model',
      'plateNumber',
      'year',
    ]);
  });

  it('update is partial but still typed', async () => {
    expect(await errorsOf(UpdateVehicleDto, { color: 'red' })).toEqual([]);
    expect(await errorsOf(UpdateVehicleDto, { year: 'x' })).toEqual(['year']);
  });
});
