import $ from 'jquery';

$(() => {
  $("*[data-action=add-email]").click(function() {
    const email = $(this).closest("tr").children(".email").text();

    const teamEmails = $("#user_team_emails");
    const currentValue = teamEmails.val();

    if (currentValue.indexOf(email) == -1) {
      teamEmails.val(`${currentValue} ${email}`);
    }
  });
});
