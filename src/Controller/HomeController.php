<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

class HomeController extends AbstractController
{
    #[Route('/', name: 'home')]
    public function index(): Response
    {
        $skills = [
            'PHP' => 90,
            'Symfony' => 85,
            'JavaScript' => 80,
            'MySQL' => 85,
            'Docker' => 75,
            'Git' => 90,
        ];

        $projects = [
            [
                'name' => 'E-Commerce Platform',
                'description' => 'Full-stack e-commerce solution with payment integration',
                'technologies' => ['Symfony', 'MySQL', 'Stripe API'],
                'link' => '#',
            ],
            [
                'name' => 'Task Management System',
                'description' => 'Collaborative project management tool with real-time updates',
                'technologies' => ['Symfony', 'WebSockets', 'Redis'],
                'link' => '#',
            ],
            [
                'name' => 'API Gateway',
                'description' => 'RESTful API with authentication and rate limiting',
                'technologies' => ['Symfony', 'JWT', 'PostgreSQL'],
                'link' => '#',
            ],
        ];

        return $this->render('home/index.html.twig', [
            'title' => 'Welcome to My Portfolio',
            'skills' => $skills,
            'projects' => $projects,
        ]);
    }
}
