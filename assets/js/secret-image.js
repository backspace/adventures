import $ from 'jquery';

$(() => {
  $('.secret .text').click(function() {
    $('.secret-image-container').attr('src', '/images/secret.gif');
  });
});
