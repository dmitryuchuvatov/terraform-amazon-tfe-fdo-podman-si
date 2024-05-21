# tfe_fdo_on_podman_in_external_services_mode.py

from diagrams import Cluster, Diagram
from diagrams.aws.general import Client
from diagrams.aws.network import Route53
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.storage import SimpleStorageServiceS3Bucket

with Diagram("TFE FDO on Podman in External Services mode", show=False, direction="TB"):
    
    client = Client("Client")
    
    with Cluster("AWS"):
        dns = Route53("DNS")
        with Cluster("VPC"):
            with Cluster("Public Subnet"):
                tfe_instance = EC2("RHEL instance")
        with Cluster("Private Subnet"):
                postgres = RDSPostgresqlInstance("PostgreSQL")

        s3bucket = SimpleStorageServiceS3Bucket("S3 bucket")        

    client >> dns
    dns >> tfe_instance
    tfe_instance >> postgres
    tfe_instance >> s3bucket