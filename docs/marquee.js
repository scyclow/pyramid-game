import {createComponent} from '../$.js'



function marquee(children, args={}) {
  const className = args.className || ''
  const style = args.style || ''
  const direction = args.direction || 1
  const delay = args.delay || 0
  const duration = args.duration || 1
  const rotate = args.rotate || 0
  const msgAnimation = args.msgAnimation || iden

  const repeat = args.repeat || 40

  const handleAnimation = (child, i, j) => {
    const spacing = (j > 0 ? 0.1 : 0.5) + 'em'
    return msgAnimation(
      $.span(
        child,
        { style: `
          margin-left: ${spacing};
          margin-right: ${spacing};
          font-size: 1em;
        ` }
      ).cloneNode(true),
      { delay: i*100 + j/2}
    )
  }



  const inner = $.div(
    times(repeat, i => Array.isArray(children)
      ? children.map((c, j) => handleAnimation(c, i, j))
      : handleAnimation(children, i, 0)
    ).flat(),
    {
      class: `marqueeInner marqueeForward`,
      style: `
        animation-delay: -${delay}s;
        animation-duration: ${duration/(repeat/40)}s;
        animation-direction: ${direction === 1 ? 'normal' : 'reverse'};
      `
    }
  )

  return $.div(
    inner,
    {
      style: style + (rotate ? `transform: rotate(${rotate}deg);` : ''),
      class: `component marquee ${className}`,
    }
  )
}

createComponent(
  'sp-marquee',
  `
    <style>
      .marquee {
        display: inline-block;
        width: 100%;
        box-sizing: border-box;
        line-height: 1;
      }

      .marqueeInner {
        display: inline-flex;
      }

      .marqueeForward {
        animation: Marquee 50s linear infinite;
      }

      .marqueeInner > * {
        display: inline-block;
        white-space: nowrap;
      }

      @keyframes Marquee {
        0% {transform: translate3d(-50%, 0, 0)}
        100% {transform: translate3d(0%, 0, 0)}
      }
    </style>

    <div id="outter" class="component marquee">

    </div>
  `,
  {},
  (ctx) => {
    const $outter = ctx.$('#outter')

    const rotate = ctx.getAttribute('rotate') || 0

    $outter.style.transform = `rotate(${rotate}deg);`

  },
  async ctx => {}
)

