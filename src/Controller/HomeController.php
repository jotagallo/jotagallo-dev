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
            'PHP' => 95,
            'Drupal' => 95,
            'Symfony' => 93,
            'Laravel' => 90,
            'JavaScript/TypeScript' => 92,
            'React & Vue.js' => 88,
            'MySQL/PostgreSQL' => 90,
            'Docker & DevOps' => 88,
            'AWS & Cloud' => 85,
            'Git & CI/CD' => 92,
        ];

        $projects = [
            [
                'name' => 'Sourceful IT Services',
                'year' => '2023 - 2024',
                'description' => 'Senior PHP/Drupal Developer and Tech Lead implementing enterprise projects for major European clients. Led teams, mentored juniors, and implemented CI/CD workflows with cloud migration.',
                'technologies' => ['Drupal 8-10', 'Symfony', 'React', 'PostgreSQL', 'Docker', 'AWS', 'Acquia'],
            ],
            [
                'name' => 'Arctouch - GSK & Quizlet',
                'year' => '2022',
                'description' => 'Tech Lead for GSK pharmaceutical internal project on Drupal 8, managing architecture and team coordination. Fullstack developer for Quizlet educational startup with web, mobile and API microservices.',
                'technologies' => ['Drupal 8', 'React', 'PostgreSQL', 'MongoDB', 'Docker', 'Kotlin'],
            ],
            [
                'name' => 'Bluetent Vacation Rentals',
                'year' => '2019 - 2022',
                'description' => 'Full-remote developer for USA-based vacation rentals software company. Developed and maintained Drupal distributions and products serving hundreds of clients nationwide.',
                'technologies' => ['Drupal 7/8', 'Laravel', 'React', 'RiotJS', 'Kubernetes', 'AWS'],
            ],
            [
                'name' => 'Opah IT Consulting',
                'year' => '2018 - 2019',
                'description' => 'Senior PHP Developer leading most of the company\'s PHP projects with major national clients. Direct allocation and development with enterprise clients using modern PHP frameworks.',
                'technologies' => ['Symfony', 'Laravel', 'PostgreSQL', 'ElasticSearch', 'Docker'],
            ],
            [
                'name' => 'GLOBANT International',
                'year' => '2016 - 2018',
                'description' => 'Part of the international Drupal team working on enterprise projects for big companies. Daily communication and collaboration with development teams around the globe.',
                'technologies' => ['Drupal 7/8', 'Laravel', 'PostgreSQL', 'Vagrant'],
            ],
            [
                'name' => 'Itelios - Telecom Portal',
                'year' => '2012 - 2014',
                'description' => 'Development of one of the biggest Brazilian telecom companies web portal. Also developed projects for major Brazilian enterprises and international advertising agencies like Ogilvy and Y&R.',
                'technologies' => ['Drupal 6/7', 'Symfony', 'Python', 'Angular', 'MySQL'],
            ],
        ];

        return $this->render('home/index.html.twig', [
            'title' => 'João Otávio Gallo - Senior Fullstack Developer',
            'skills' => $skills,
            'projects' => $projects,
        ]);
    }
}
