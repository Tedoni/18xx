# frozen_string_literal: true

require 'lib/publisher'

module View
  class Welcome < Snabberb::Component
    needs :app_route, default: nil, store: true

    def render
      children = [render_notification]
      children << render_introduction
      children << render_buttons

      h('div#welcome.half', children)
    end

    def render_notification
      message = <<~MESSAGE
        <p><a href='https://www.kickstarter.com/projects/18wood/18royalgorge/'>18RoyalGorge is now on Kickstarter</a>.</p>

        <p><a href="https://github.com/tobymao/18xx/wiki/18RoyalGorge">18RoyalGorge</a> is now in beta.</p>

        <p><a href="https://github.com/tobymao/18xx/wiki/1858%20Switzerland">1858 Switzerland</a> is in alpha.</p>

        <p>Report bugs and make feature requests <a href='https://github.com/tobymao/18xx/issues'>on GitHub</a>.</p>
      MESSAGE

      props = {
        style: {
          background: 'rgb(240, 229, 140)',
          color: 'black',
          marginBottom: '1rem',
        },
        props: {
          innerHTML: message,
        },
      }

      h('div#notification.padded', props)
    end

    def render_introduction
      message = <<~MESSAGE
        <p>This is a test implementation of Age of Steam built off of the 18xx.games framework</p>
      MESSAGE

      props = {
        style: {
          marginBottom: '1rem',
        },
        props: {
          innerHTML: message,
        },
      }

      h('div#introduction', props)
    end

    def render_buttons
      props = {
        style: {
          margin: '1rem 0',
        },
      }

      create_props = {
        on: {
          click: -> { store(:app_route, '/new_game') },
        },
      }

      tutorial_props = {
        on: {
          click: -> { store(:app_route, '/tutorial?action=1') },
        },
      }

      h('div#buttons', props, [
        h(:button, create_props, 'CREATE A NEW GAME'),
        h(:button, tutorial_props, 'TUTORIAL'),
      ])
    end
  end
end
