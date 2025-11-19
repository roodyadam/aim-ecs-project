

ECS-Project-Coderco/
├── README.md                    # Project documentation
├── .gitignore                   # Git ignore rules
├── .github/
│   └── workflows/
│       └── deploy.yml           # CI/CD pipeline
├── infra/                       # Terraform infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── modules/                 # Terraform modules
└── aim/                         # Application code
    ├── main.py
    ├── docker/
    └── ...                      # Application files