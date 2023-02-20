import EmberObject from '@ember/object';
import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';

module(
  'Unit | Service | Clandestine Rendezvous | chooseBlankIndex',
  function (hooks) {
    setupTest(hooks);

    test('it chooses a blank index', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      assert.equal(
        service.chooseBlankIndex({
          answer: '123',
          mask: '1_3',
          goalDigit: 9,
        }),
        1,
        'expected the only blank index'
      );

      assert.equal(
        service.chooseBlankIndex({
          answer: '321',
          mask: '___',
          goalDigit: 9,
        }),
        2,
        'expected the farthest-away blank index'
      );

      assert.equal(
        service.chooseBlankIndex({
          answer: '222',
          mask: '___',
          goalDigit: 9,
        }),
        0,
        'expected the first farthest-away blank index'
      );
    });

    test('throws if the answer and mask have a mismatch', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      assert.throws(() => {
        service.chooseBlankIndex({
          answer: '123',
          mask: '1_5',
          goalDigit: 9,
        });
      }, 'expected an error when a non-masked digit did not match');

      assert.throws(() => {
        service.chooseBlankIndex({
          answer: '123',
          mask: '1_34',
          goalDigit: 9,
        });
      }, 'expected an error when the mask was longer than the answer');

      assert.throws(() => {
        service.chooseBlankIndex({
          answer: '123',
          mask: '123',
          goalDigit: 9,
        });
      }, 'expected an error when the mask had no blanks');
    });
  }
);

module(
  'Unit | Service | Clandestine Rendezvous | teamDigitsForAnswerAndGoalDigits',
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.teamA = EmberObject.create({ name: 'A team' });
      this.teamB = EmberObject.create({ name: 'B team' });

      this.teams = [this.teamA, this.teamB];
      this.reversedTeams = [this.teamB, this.teamA];
    });

    test('assigns the entire difference to the team if there is only one', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      let teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({
        teams: [this.teamA],
        answerDigit: 3,
        goalDigit: 7,
      });

      assert.equal(teamToDigitMap.get(this.teamA), 4);

      teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({
        teams: [this.teamA],
        answerDigit: 8,
        goalDigit: 2,
      });

      assert.equal(teamToDigitMap.get(this.teamA), -6);
    });

    test('splits the difference between teams', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      let teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({
        teams: this.teams,
        answerDigit: 3,
        goalDigit: 7,
      });

      assert.equal(teamToDigitMap.get(this.teamA), 2);
      assert.equal(teamToDigitMap.get(this.teamB), 2);

      teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({
        teams: this.teams,
        answerDigit: 3,
        goalDigit: 8,
      });

      assert.equal(teamToDigitMap.get(this.teamA), 3);
      assert.equal(teamToDigitMap.get(this.teamB), 2);

      teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({
        teams: this.reversedTeams,
        answerDigit: 3,
        goalDigit: 8,
      });

      assert.equal(
        teamToDigitMap.get(this.teamA),
        3,
        'expected the alphabetically-first team to get the larger portion'
      );
      assert.equal(
        teamToDigitMap.get(this.teamB),
        2,
        'expected the alphabetically-last team to get the smaller portion'
      );
    });

    test('throws if there are more than two teams', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      assert.throws(() => {
        service.teamDigitsForAnswerAndGoalDigits({
          teams: [this.teamA, this.teamA, this.teamA],
        });
      }, 'expected an error with more than one team');
    });

    test('throws if there no teams', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      assert.throws(() => {
        service.teamDigitsForAnswerAndGoalDigits({ teams: [] });
      }, 'expected an error with no teams');
    });
  }
);

module(
  'Unit | Service | Clandestine Rendezvous | maskIsValid',
  function (hooks) {
    setupTest(hooks);

    test('it checks mask validity', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      assert.ok(
        service.maskIsValid('ABC123', 'ABC___'),
        'expected the mask to be valid when it matches the answer'
      );
      assert.ok(
        service.maskIsValid('ABC123', 'ABC1_3'),
        'expected the mask to be valid when it masks a subset of the answer'
      );

      assert.notOk(
        service.maskIsValid('ABC123', 'AB___'),
        'expected the mask to be invalid when it’s a different length'
      );
      assert.notOk(
        service.maskIsValid('ABD123', 'ABC___'),
        'expected the mask to be invalid when a letter differs'
      );
      assert.notOk(
        service.maskIsValid('ABC123', 'ABC123'),
        'expected the mask to be invalid when it has no blanks'
      );
    });
  }
);

module(
  'Unit | Service | Clandestine Rendezvous | suggestedMask',
  function (hooks) {
    setupTest(hooks);

    test('it suggests masks', function (assert) {
      const service = this.owner.lookup('service:clandestine-rendezvous');

      assert.equal(
        service.suggestedMask('ABC123'),
        'ABC___',
        'expected a suggested mask'
      );
      assert.equal(
        service.suggestedMask('A0C1234'),
        'A0C1___',
        'expected the suggested mask to blank the three rightmost digits'
      );
    });
  }
);
