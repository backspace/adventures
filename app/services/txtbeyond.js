import classic from 'ember-classic-decorator';
import Service from '@ember/service';
import { all } from 'rsvp';

@classic
export default class TxtbeyondService extends Service {
  suggestedMask(answer) {
    return answer.split(' ').map((word, index, array) => {
      if (index === 1 || array.length === 1) {
        return '_'.repeat(word.length);
      } else {
        return word;
      }
    }).join(' ');
  }

  maskIsValid(answer, mask) {
    if (answer.length !== mask.length) {
      return false;
    }

    for (let i = 0; i < answer.length; i++) {
      const answerCharacter = answer[i];
      const maskCharacter = mask[i];

      if (answerCharacter !== maskCharacter) {
        if (maskCharacter !== '_') {
          return false;
        }
      }
    }

    return mask.indexOf('_') > -1;
  }

  descriptionIsValid(description) {
    const tildeCount = (description.match(/~/g) || []).length;

    return tildeCount > 0 && tildeCount % 2 === 0;
  }

  maskedDescription(description) {
    return description.replace(/~([^~]*)~/g, (s) => '_'.repeat(s.length - 2));
  }

  descriptionMasks(description) {
    return description.match(/~([^~]*)~/g).map(s => s.slice(1, s.length - 1));
  }

  twitterName(name) {
    return name.toLowerCase().replace(/\s+/g, '_').replace(/\W/g, '').slice(0, 15);
  }

  assignMeetingPhones(teams, meetings) {
    const phoneNumberToTeam = teams.reduce((phoneNumberToTeam, team) => {
      (team.get('phones') || []).forEach(phone => phoneNumberToTeam[phone.number] = team);
      return phoneNumberToTeam;
    }, {});

    meetings.rejectBy('number').forEach(meeting => {
      const phones = meeting.get('teams').reduce((phones, team) => {
        return phones.concat(team.get('phones'));
      }, []);

      const phoneNumberToCount = phones.reduce((phoneNumberToCount, phone) => {
        phoneNumberToCount[phone.number] = phone.meetingCount || 0;
        return phoneNumberToCount;
      }, {});

      const minimumCount = Math.min(...Object.values(phoneNumberToCount));

      const phoneNumbersWithMinimumCount = Object.keys(phoneNumberToCount).filter(phoneNumber => {
        return phoneNumberToCount[phoneNumber] === minimumCount;
      });

      const randomPhoneNumber = phoneNumbersWithMinimumCount[Math.floor(Math.random() * phoneNumbersWithMinimumCount.length)];

      this._incrementTeamPhoneMeetingCount(phoneNumberToTeam[randomPhoneNumber], randomPhoneNumber);
      meeting.set('phone', randomPhoneNumber);
    });

    return all(teams.map(team => team.save()).concat(meetings.map(meeting => meeting.save())));
  }

  _incrementTeamPhoneMeetingCount(team, number) {
    const foundPhone = (team.get('phones') || []).findBy('number', number);

    if (!foundPhone) {
      throw new Error(`Unable to find number ${number} under team ${team.id}!`);
    }

    if (!foundPhone.meetingCount) {
      foundPhone.meetingCount = 0;
    }

    foundPhone.meetingCount++;
  }
}
