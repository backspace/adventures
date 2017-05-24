(function() {
  var $;

  $ = jQuery;

  $.fn.extend({
    draggableNumber: function(options) {
      var getY;
      getY = function(event) {
        if (event.touches) {
          return event.touches[0].pageY;
        } else {
          return event.pageY;
        }
      };
      return this.each(function() {
        var divisor, fraction, max, min, numberField, startValue, startY, started;
        startValue = void 0;
        startY = void 0;
        started = false;
        numberField = $(this);
        divisor = 10.0;
        fraction = 1 / parseFloat(numberField.attr('step'));
        max = parseFloat(numberField.attr('max')) || Number.MAX_VALUE;
        min = parseFloat(numberField.attr('min'));
        numberField.bind('mousedown touchstart', (function(_this) {
          return function(event) {
            var value;
            $(document.body).addClass('draglessness');
            started = true;
            startY = getY(event.originalEvent);
            value = numberField.val();
            startValue = value === NaN || value === "" ? 0 : parseFloat(value);
          };
        })(this));
        $('body').bind('mousemove touchmove', (function(_this) {
          return function(event) {
            var dy, rounded, y;
            if (started) {
              y = getY(event.originalEvent);
              dy = y - startY;
              rounded = Math.round(dy / divisor) / fraction;
              numberField.val(Math.min(Math.max(min, startValue - rounded), max));
              event.preventDefault();
              return numberField.trigger('keyup');
            }
          };
        })(this));
        return $('body').bind('mouseup touchend', (function(_this) {
          return function(event) {
            $(document.body).removeClass('draglessness');

            if (started) {
              started = false;
              event.preventDefault();
            }
          };
        })(this));
      });
    }
  });

}).call(this);
