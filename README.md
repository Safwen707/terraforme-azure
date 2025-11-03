# terraforme-azure

Description
-----------
Ce dépôt contient des templates Terraform pour déployer une petite infrastructure sur Microsoft Azure : réseau (VNet, Subnet), sécurité (NSG + règles), adresse publique, interface réseau et une VM Linux (Ubuntu 22.04) provisionnée automatiquement pour installer Docker via `cloud-init`.

Fichiers importants
-------------------
- `main.tf` : définition complète des ressources Azure (Resource Group, VNet, Subnet, NSG, règles, association NSG→subnet, Public IP, NIC, VM, etc.).
- `customdata.tpl` : script `cloud-init` (user data) qui installe Docker au premier démarrage de la VM.
- `ubuntu-ssh-script.tpl` : template pour ajouter une configuration SSH dans `~/.ssh/config` (facilite les connexions / VS Code Remote).
- `terraform.tfstate` : état local Terraform (ne pas committer en production).

Prérequis
---------
- Terraform installé (v1.x compatible) et provider `azurerm` (géré dans `main.tf`).
- Azure CLI ou variables d'environnement ARM pour l'authentification :
	- `ARM_SUBSCRIPTION_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID` 
	- ou `az login` si vous utilisez l'Azure CLI pour authentifier Terraform.
- Clé SSH disponible localement (ex. `~/.ssh/id_rsa` et `~/.ssh/id_rsa.pub`).

Déploiement (rapide)
---------------------
1. Initialiser Terraform :

	 ```bash
	 terraform init
	 ```

2. Vérifier le plan :

	 ```bash
	 terraform plan
	 ```

3. Appliquer la configuration :

	 ```bash
	 terraform apply
	 ```

Notes importantes
-----------------
- Public IP SKU : selon votre abonnement/région, la création d'une Public IP en SKU `Basic` peut être limitée. Le code utilise `Standard`/`Static` si nécessaire — adaptez la configuration si vous préférez une allocation dynamique (`Dynamic`) mais attention aux limites de SKU/quotas.
- `custom_data` (cloud-init) : le script de bootstrap peut retarder la disponibilité SSH jusqu'à la fin de l'installation (Docker). En cas de timeout SSH, attendez quelques minutes et retentez.
- `terraform.tfstate` : contient l'état local. Pour du travail en équipe ou production, configurez un backend distant (Azure Blob Storage) pour partager l'état.

Dépannage rapide
----------------
- Erreur `subscription_id` manquant : exportez `ARM_SUBSCRIPTION_ID` ou configurez les variables ARM avant `terraform plan`/`apply`.
- Host key changed / `known_hosts` : si la VM est recréée, supprimez l'ancienne entrée :

	```bash
	ssh-keygen -f ~/.ssh/known_hosts -R <PUBLIC_IP>
	```

- Problème de clé SSH : (regénérer) :

	```bash
	ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''
	```

- VS Code Remote : ajoutez une entrée à `~/.ssh/config` (ou utilisez `ubuntu-ssh-script.tpl`) pour simplifier la connexion :

	```text
	Host mtc-vm
		HostName <PUBLIC_IP>
		User adminuser
		IdentityFile ~/.ssh/id_rsa
	```

Bonnes pratiques & conseils
--------------------------
- Préférez `cloud-init` / VM extensions / images pré-baked pour le provisioning systématique (plus robuste que les provisioners Terraform). 
- Ne stockez pas `terraform.tfstate` dans un dépôt public et évitez d’y laisser des secrets en clair.
- Testez les changements locaux (`plan`) avant d’appliquer en production.

Pour aller plus loin
--------------------
Si vous voulez, je peux :
- ajouter un `backend` Azure Blob pour centraliser l'état Terraform,
- préparer un script d'automatisation CI (GitHub Actions) pour déployer automatiquement, 
- publier le repo avec un README en anglais aussi.

Contact
-------
Si vous voulez le repo public ou une walkthrough pas‑à‑pas, dites‑moi et je publie les fichiers et instructions détaillées.

# terraforme-azure
# terraforme-azure
