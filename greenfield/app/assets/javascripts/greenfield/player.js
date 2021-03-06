//= require greenfield/sound
//= require greenfield/waveform

function attr(val) {
  return val.replace(/\//g, '\\/').replace(/@/g, '\\@');
}

function waveformData(csv) {
  var data = csv.split(',').map(function(s) {
    return parseFloat(s);
  });

  var max = Math.max.apply(Math, data),
      min = Math.min.apply(Math, data);
  var scale = Math.max(Math.abs(max), Math.abs(min));
  data = data.map(function(s) {
    return (s < 0 ? -1 : 1 ) * Math.pow(Math.abs(s) / scale, 0.7);
  });

  return data;
}

function toggleCover(href){
  var cover = $('.playlist a.small-cover');
  var sidebarDownloads = $('.sidebar-downloads')
  if (cover[0].href == href){
    cover.hide();
    sidebarDownloads.hide();
  }else{
    cover.show();
    sidebarDownloads.show();
  }
}

function showWaveform() {
  $('.waveform').each(function() {
    var container = $(this);
    var player = $(this).parents('.player');
    var seekbar = player.find('.seekbar');
    var data = waveformData($(this).data('waveform'));
    var soundId = $(this).parent('[data-sound-id]').data('sound-id');
    $(this).removeAttr('data-waveform');

    var soundPosition = 0;
    container.on('update.waveform', function(e, sound) {
      soundPosition = sound.position;
      container.data('waveform').update({ data: data });
    });

    container.data('waveform', new Waveform({
      container: this,
      height: 54,
      innerColor: function(percent, _) {
        if (percent < soundPosition)
          return '#302f2f';
        else
          return '#c7c6c3';
      },
      data: data
    }));

    container.click(function(e) {
      e.preventDefault();

      $('[data-sound-id]').filter(function() {
          return $(this).data('sound-id') != soundId;
      }).find('.pause-button').trigger('click');

      var sound, offx;
      sound = Sound.getSound(soundId);
      offx = e.clientX - container.offset().left;
      sound.setPosition(offx / container.width()).play();
    });

    container.mousemove(function(e) {
      var offx = e.clientX - container.offset().left;
      hoverPosition = offx / container.width();
      seekbar.css('left', offx);
    }).mouseout(function() { hoverPosition = -1 });

    soundManager.onready(function() {
      var sound = Sound.load(player.find('.play-control a').attr('href'));

      sound.resumed(function() {
        changeControlActionToPause(soundId);
      });

      sound.paused(function() {
        changeControlActionToPlay(soundId);
      });

      sound.playing(function() {
        container.trigger('update.waveform', [this]);
        player.find('.time .index').text(this.index);
      });
    });
  });
}

function changeControlActionToPlay(soundId) {
  var controls = $('[data-sound-id='+attr(soundId)+'] .play-button,'+
                   '[data-sound-id='+attr(soundId)+'] .pause-button');
  controls.removeClass('pause-button').addClass('play-button').
    find('*').andSelf().filter('.fa-pause').removeClass('fa-pause').addClass('fa-play');
}

function changeControlActionToPause(soundId) {
  var controls = $('[data-sound-id='+attr(soundId)+'] .play-button,'+
                   '[data-sound-id='+attr(soundId)+'] .pause-button');
  controls.removeClass('play-button').addClass('pause-button').
    find('*').andSelf().filter('.fa-play').removeClass('fa-play').addClass('fa-pause');
}

function mobileHTML5() {
  // Use the same test as soundmanager2
  var ua = navigator.userAgent,
      isAndroid = ua.match(/android/i),
      is_iDevice = ua.match(/(ipad|iphone|ipod)/i);
  return ua.match(/(mobile|pre\/|xoom)/i) || is_iDevice || isAndroid;
}

Playlist = [];

soundManager.onready(function() {
  var as = $('.tracklist [data-sound-id] a.play-button');
  if (!as.length)
    as = $('.play-button a, .pause-button a');

  as.each(function(i) {
    var url = this.attributes.href.nodeValue;
    var sound = Sound.load(this.pathname.replace(/(\.mp3)*$/, '.mp3'));
    Playlist.push(sound);

    sound.ui = this;

    sound.positioned(5000, function() {
      $.post(url.replace(/\.mp3$/, '') + '/listens');
    });

    sound.paused(function() {
      changeControlActionToPlay(this.id);
      window['ga'] && window.ga('send', 'event', 'stream', 'stop', this.id);
    });

    sound.resumed(function() {
      changeControlActionToPause(this.id);
      window['ga'] && window.ga('send', 'event', 'stream', 'play', this.id);
    });

    sound.finished(function() {
      changeControlActionToPlay(this.id);
    });
  });

  $.each(Playlist, function(i, sound) {
    var next = Playlist[i+1];

    if (mobileHTML5()) {
      sound.finished(function() {
        next && $(next.ui).trigger('click');
      });
    } else {
      sound.positioned(-10000, function() {
        next && next.load();
      });

      sound.positioned(-180, function() {
        next && $(next.ui).trigger('click');
      });
    }
  });

  var currentTrack = $('.player .play-control a').attr('href');
  if (currentTrack)
    Sound.load(currentTrack).load();
});

$('body').on('click', '.track-content > .player .play-button,' +
                      '.tracklist [data-sound-id] .play-button', function(e) {
  var soundId = $(this).parent('[data-sound-id]').data('sound-id');
  var li = $('.playlist li[data-sound-id=' + attr(soundId) + ']');

  // Pause other tracks unless this event was triggered programmatically
  if (!e.isTrigger)
    Sound.pauseAll();

  var sound = Sound.load(soundId)
  if (sound.id != Sound.getId(window.location.pathname))
    sound.setPosition(0)
  sound.play();

  if (window.location.href == this.href) {
    e.preventDefault();
    return false;
  }
});

$('body').on('click', '.post-content > .player .play-button', function(e) {
  var url = $(this).find('a').attr('href');
  var soundId = $(this).parent('[data-sound-id]').data('sound-id');
  var sound = Sound.load(url);

  sound.finished(null).finished(function() {
    changeControlActionToPlay(this.id);
  });

  Sound.pauseAll();
  sound.play();
});

$('body').on('click', '[data-sound-id] .pause-button', function(e) {
  var soundId = $(this).parent('[data-sound-id]').data('sound-id');

  Sound.pause(soundId);

  e.preventDefault();
  return false;
});

$('body').on('ajax:success', '.playlist a[data-remote]', function(e, data) {
  var hasDetails = $('body').hasClass('has-details');
  if(hasDetails){
    toggleCover(e.target.href);
    $('.track-content').replaceWith($(data).find('.track-content'));
    showWaveform();
  }

  $('.playlist .tracklist li').removeClass('active');
  $(e.target).parent('li').addClass('active');

  $('.player .play-button').each(function() {
    var url = $(this).find('*').andSelf().filter('a').attr('href');
    if (!mobileHTML5())
      soundManager.onready(function() { Sound.load(url).load() });
  });

  if (hasDetails && window.history.pushState && e.target.href != document.location.href)
    window.history.pushState(null, '', e.target.href);
});

$(window).on('popstate', function(je) {
  var loc = document.location.pathname;
  var link = $('.playlist a[data-remote=true][href='+attr(loc)+']').last();
  link.trigger('click');
});

$(document).ready(showWaveform);
