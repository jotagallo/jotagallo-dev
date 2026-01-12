// Toggle experience timeline
document.addEventListener('DOMContentLoaded', function() {
    // Mobile menu toggle
    const mobileMenuButton = document.getElementById('mobile-menu-button');
    const mobileMenu = document.getElementById('mobile-menu');
    
    if (mobileMenuButton && mobileMenu) {
        mobileMenuButton.addEventListener('click', function() {
            mobileMenu.classList.toggle('hidden');
        });

        // Close mobile menu when clicking a link
        const mobileLinks = mobileMenu.querySelectorAll('a');
        mobileLinks.forEach(link => {
            link.addEventListener('click', function() {
                mobileMenu.classList.add('hidden');
            });
        });
    }

    // Toggle experience timeline
    const toggleBtn = document.getElementById('toggleExperience');
    const hiddenItems = document.querySelectorAll('.timeline-item-hidden');
    let isExpanded = false;

    if (toggleBtn) {
        toggleBtn.addEventListener('click', function() {
            isExpanded = !isExpanded;
            
            hiddenItems.forEach(item => {
                if (isExpanded) {
                    item.classList.add('show');
                } else {
                    item.classList.remove('show');
                }
            });
            
            toggleBtn.textContent = isExpanded ? 'Show Less Experience' : 'Show More Experience';
        });
    }

    // Smooth scroll for navigation links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const href = this.getAttribute('href');
            if (href !== '#' && href.length > 1) {
                e.preventDefault();
                const target = document.querySelector(href);
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            }
        });
    });
});
