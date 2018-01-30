import EmberObject from '@ember/object';
import { moduleFor, test } from 'ember-qunit';

moduleFor('service:puzzles', 'Unit | Service | puzzles | chooseBlankIndex');

test('it chooses a blank index', function(assert) {
  const service = this.subject();

  assert.equal(
    service.chooseBlankIndex({
      answer: '123',
      mask: '1_3',
      goalDigit: 9
    }),
  1, 'expected the only blank index');

  assert.equal(
    service.chooseBlankIndex({
      answer: '321',
      mask: '___',
      goalDigit: 9
    }),
  2, 'expected the farthest-away blank index');

  assert.equal(
    service.chooseBlankIndex({
      answer: '222',
      mask: '___',
      goalDigit: 9
    }),
  0, 'expected the first farthest-away blank index');
});

test('throws if the answer and mask have a mismatch', function(assert) {
  const service = this.subject();

  assert.throws(() => {
    service.chooseBlankIndex({
      answer: '123',
      mask: '1_5',
      goalDigit: 9
    });
  }, 'expected an error when a non-masked digit did not match');

  assert.throws(() => {
    service.chooseBlankIndex({
      answer: '123',
      mask: '1_34',
      goalDigit: 9
    });
  }, 'expected an error when the mask was longer than the answer');

  assert.throws(() => {
    service.chooseBlankIndex({
      answer: '123',
      mask: '123',
      goalDigit: 9
    });
  }, 'expected an error when the mask had no blanks');
});

moduleFor('service:puzzles', 'Unit | Service | puzzles | teamDigitsForAnswerAndGoalDigits', {
  beforeEach() {
    this.teamA = EmberObject.create({name: 'A team'});
    this.teamB = EmberObject.create({name: 'B team'});

    this.teams = [this.teamA, this.teamB];
    this.reversedTeams = [this.teamB, this.teamA];
  }
});

test('assigns the entire difference to the team if there is only one', function(assert) {
  const service = this.subject();

  let teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({teams: [this.teamA], answerDigit: 3, goalDigit: 7});

  assert.equal(teamToDigitMap.get(this.teamA), 4);

  teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({teams: [this.teamA], answerDigit: 8, goalDigit: 2});

  assert.equal(teamToDigitMap.get(this.teamA), -6);
});

test('splits the difference between teams', function(assert) {
  const service = this.subject();

  let teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({teams: this.teams, answerDigit: 3, goalDigit: 7});

  assert.equal(teamToDigitMap.get(this.teamA), 2);
  assert.equal(teamToDigitMap.get(this.teamB), 2);

  teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({teams: this.teams, answerDigit: 3, goalDigit: 8});

  assert.equal(teamToDigitMap.get(this.teamA), 3);
  assert.equal(teamToDigitMap.get(this.teamB), 2);

  teamToDigitMap = service.teamDigitsForAnswerAndGoalDigits({teams: this.reversedTeams, answerDigit: 3, goalDigit: 8});

  assert.equal(teamToDigitMap.get(this.teamA), 3, 'expected the alphabetically-first team to get the larger portion');
  assert.equal(teamToDigitMap.get(this.teamB), 2, 'expected the alphabetically-last team to get the smaller portion');
});

test('throws if there are more than two teams', function(assert) {
  const service = this.subject();

  assert.throws(() => {
    service.teamDigitsForAnswerAndGoalDigits({teams: [this.teamA, this.teamA, this.teamA]});
  }, 'expected an error with more than one team');
});

test('throws if there no teams', function(assert) {
  const service = this.subject();

  assert.throws(() => {
    service.teamDigitsForAnswerAndGoalDigits({teams: []});
  }, 'expected an error with no teams');
});
