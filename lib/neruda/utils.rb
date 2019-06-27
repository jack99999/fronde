# frozen_string_literal: true

require 'rainbow'
require 'neruda/config'

module Neruda
  # The Neruda::Utils module embed usefull methods, mainly used in rake
  # tasks
  module Utils
    THROBBER_FRAMES = {
      'basic' => '-\|/',
      'basicdots' => '⋯⋱⋮⋰',
      'moon' => '🌑🌒🌓🌔🌕🌖🌗🌘',
      'clock' => '🕛🕐🕑🕒🕓🕔🕕🕖🕗🕘🕙🕚',
      'bricks' => '⣾⣽⣻⢿⡿⣟⣯⣷',
      'points' => '·⁘∷⁛∷⁘',
      'quadrant2' => '▙▛▜▟',
      'default' => ['⠁ ⠂ ⠄ ⡀ ⠄ ⠂ ⠁', '⠂ ⠁ ⠂ ⠄ ⡀ ⠄ ⠂', '⠄ ⠂ ⠁ ⠂ ⠄ ⡀ ⠄',
                    '⡀ ⠄ ⠂ ⠁ ⠂ ⠄ ⡀', '⠄ ⡀ ⠄ ⠂ ⠁ ⠂ ⠄', '⠂ ⠄ ⡀ ⠄ ⠂ ⠁ ⠂']
    }.freeze

    class << self
      def throbber(thread, message)
        if Neruda::Config.settings['TEST'] == 'test'
          thread.join
          return puts_point
        end
        model = Neruda::Config.settings['throbber'] || 'default'
        model = 'default' unless Neruda::Utils::THROBBER_FRAMES.has_key?(model)
        frames = Neruda::Utils::THROBBER_FRAMES[model]
        current = 0
        while thread.alive?
          sleep 0.1
          print "#{message} #{frames[current % frames.length]}\r"
          current += 1
        end
        done = Rainbow('done'.ljust(frames[0].length)).green
        puts "#{message} #{done}"
      end

      def puts_point(color = :blue)
        print Rainbow('.').send(color)
      end
    end
  end
end
