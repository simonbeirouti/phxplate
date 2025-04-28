export const AdminSwitcher = {
  mounted() {
    this.handleRoleSwitch();
  },

  handleRoleSwitch() {
    const menuItems = document.querySelectorAll('[data-role-switch]');
    
    menuItems.forEach(item => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        const role = item.dataset.roleSwitch;
        
        // Store the selected role in localStorage
        localStorage.setItem('tempAdminRole', role);
        
        // Add the role as a query parameter and reload
        const url = new URL(window.location.href);
        url.searchParams.set('temp_role', role);
        window.location.href = url.toString();
      });
    });
  }
}; 