// Adapted from https://github.com/BobrImperator/emberfest-validations/blob/master/app/validations/yup.js

import { getProperties } from '@ember/object';
import { addMethod, array, object, setLocale } from 'yup';

export default class YupValidations {
  context = null;
  schema = null;
  shape = null;

  constructor(context, shape) {
    this.context = context;
    this.shape = shape;
    this.schema = object().shape(shape);
  }

  get fieldErrors() {
    try {
      this.schema.validateSync(this.#validationProperties(), {
        abortEarly: false,
        context: this.#validationProperties(),
      });

      return [];
    } catch (error) {
      return error.errors.reduce((acc, validationError) => {
        const key = validationError.path;

        if (!acc[key]) {
          acc[key] = [validationError];
        } else {
          acc[key].push(validationError);
        }

        return acc;
      }, {});
    }
  }

  #validationProperties() {
    return getProperties(this.context, ...Object.keys(this.shape));
  }
}

const locale =
  (key, localeValues = []) =>
  (validationParams) => ({
    key,
    path: validationParams.path,
    values: getProperties(validationParams, ...localeValues),
  });

setLocale({
  mixed: {
    default: locale('invalid'),
    required: locale('required'),
    oneOf: locale('oneOf', ['values']),
    notOneOf: locale('notOneOf', ['values']),
    defined: locale('defined'),
  },
});

function extendYup() {
  addMethod(object, 'relationship', function () {
    return this.test(function (value) {
      return value.validations.validate();
    });
  });

  addMethod(array, 'relationship', function () {
    return this.transform(
      (_value, originalValue) => originalValue?.toArray() || [],
    ).test(async function (value) {
      const validationsPassed = await Promise.all(
        value.map(({ validations }) => {
          return validations.validate();
        }),
      );

      return validationsPassed.every((validation) => validation === true);
    });
  });
}

extendYup();
