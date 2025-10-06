# deployml

Welcome to deployml, a python library for deploying an end-to-end machine learning operations infrastructure in the cloud.

## Why was deployml created?

deployml was created to facilitate the learning of the MLOps pipeline and processes. It is not easy to get hands-on practice with MLOps, particularly on a laptop, and provisioning an entire MLOps infrastructure can be prohibitively difficult, resulting in many hours of wasted time debugging configuration issues. The goal of deployml is to make the infrastructure part just a little bit easier so that more time can be spent on actually using the infrastructure to practice with developing, deploying, and monitoring machine learning models. 

There is a lot that can be learned by struggling with getting infrastructure to work - but we've noticed that when students spend what precious time they have simply "getting it to work", they have no fuel left to explore the different stages of the MLOps pipeline. We hope that this tool gives them that freedom, while at the same, can be used as a learning tool for docker, kubernetes, terraform, and cloud computing. 

## Who is deployml for?

deployml was created for instructors and students of MLOps. It was not designed to be used by companies seeking a tool for MLOps infrastructure. 

## What does deployml do?

deployml will provision the infrastructure needed for a basic end-to-end MLOps pipeline in Google Cloud Platform, which includes the following components:

- experiment tracking  
- model and artifact tracking and model registration  
- feature store   
- ML pipelines (e.g. training and scoring pipelines)  
- online and offline model deployment  
- model monitoring  

What is currently not included in the pipeline is:

- anything to do with LLMs and generative AI  
- scalable model development  
- data versioning and data pipelines    

In future releases, we hope to extend deployml to AWS, and make more open source tools available for the different components.