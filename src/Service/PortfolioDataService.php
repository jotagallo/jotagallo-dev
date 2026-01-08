<?php

namespace App\Service;

use Symfony\Component\Yaml\Yaml;

class PortfolioDataService
{
    private array $data;

    public function __construct(string $projectDir)
    {
        $dataFile = $projectDir . '/config/data/portfolio.yaml';
        $this->data = Yaml::parseFile($dataFile);
    }

    public function getTitle(): string
    {
        return $this->data['title'] ?? 'Portfolio';
    }

    public function getSkills(): array
    {
        return $this->data['skills'] ?? [];
    }

    public function getProjects(): array
    {
        return $this->data['projects'] ?? [];
    }

    public function getExperience(): array
    {
        return $this->data['experience'] ?? [];
    }

    public function getAllData(): array
    {
        return $this->data;
    }
}
