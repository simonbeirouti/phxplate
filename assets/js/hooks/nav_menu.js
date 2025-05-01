const NavMenu = {
  mounted() {
    const menu = document.getElementById('mobile-menu')
    const menuIcon = document.getElementById('menu-icon')
    const closeIcon = document.getElementById('close-icon')
    const button = this.el

    this.closeMenu = () => {
      menu.style.transition = 'opacity 75ms ease-in, transform 75ms ease-in'
      menu.style.opacity = '0'
      menu.style.transform = 'scale(0.95)'
      
      setTimeout(() => {
        menu.classList.add('hidden')
        if (menuIcon && closeIcon) {
          menuIcon.classList.remove('hidden')
          closeIcon.classList.add('hidden')
        }
        // Reset styles after animation
        menu.style.transition = ''
        menu.style.opacity = ''
        menu.style.transform = ''
      }, 75)
    }

    this.openMenu = () => {
      menu.classList.remove('hidden')
      if (menuIcon && closeIcon) {
        menuIcon.classList.add('hidden')
        closeIcon.classList.remove('hidden')
      }
      menu.style.opacity = '0'
      menu.style.transform = 'scale(0.95)'
      
      // Force a reflow
      menu.offsetHeight
      
      menu.style.transition = 'opacity 100ms ease-out, transform 100ms ease-out'
      menu.style.opacity = '1'
      menu.style.transform = 'scale(1)'
    }

    this.handleResize = () => {
      if (window.innerWidth >= 768 && !menu.classList.contains('hidden')) {
        this.closeMenu()
      }
    }

    this.handleClick = () => {
      if (menu.classList.contains('hidden')) {
        this.openMenu()
      } else {
        this.closeMenu()
      }
    }

    window.addEventListener('resize', this.handleResize)
    button.addEventListener('click', this.handleClick)
  },

  destroyed() {
    window.removeEventListener('resize', this.handleResize)
    const button = this.el
    if (button) {
      button.removeEventListener('click', this.handleClick)
    }
  }
}

export default NavMenu
