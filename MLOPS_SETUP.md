# 🤖 GreenAI MLOps Pipeline Setup Guide

This guide covers setting up a complete MLOps pipeline for YOLO model training, versioning, and deployment using Airflow and MLflow.

## 🏗️ **MLOps Architecture**

```
Data → Airflow (Orchestration) → YOLO Training → MLflow (Versioning) → A/B Testing → Production Deployment
```

### **Components:**
- **Airflow**: Workflow orchestration and scheduling
- **MLflow**: Model versioning, registry, and experiment tracking
- **YOLO**: Computer vision model for crop disease detection
- **PostgreSQL**: Metadata storage for Airflow and MLflow
- **Redis**: Message broker for Airflow Celery executor
- **S3**: Artifact storage for MLflow models

## 🔐 **Required Secrets**

### **GitHub Actions Secrets**
Add these secrets to your GitHub repository:

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key

# Application Secrets
GEMINI_API_KEY=your-gemini-api-key

# Monitoring
GRAFANA_ADMIN_PASSWORD=your-secure-grafana-password

# MLflow Database
MLFLOW_DB_PASSWORD=your-secure-mlflow-db-password

# Airflow Configuration
AIRFLOW_DB_PASSWORD=your-secure-airflow-db-password
AIRFLOW_FERNET_KEY=your-32-character-fernet-key
AIRFLOW_SECRET_KEY=your-airflow-webserver-secret-key
```

### **Generate Required Keys**

```python
# Generate Airflow Fernet Key
from cryptography.fernet import Fernet
fernet_key = Fernet.generate_key()
print(fernet_key.decode())

# Generate Airflow Secret Key
import secrets
secret_key = secrets.token_urlsafe(32)
print(secret_key)
```

## 🚀 **Deployment Steps**

### **1. Configure Environment Variables**

```bash
# Set all required environment variables
export TF_VAR_gemini_api_key="your-gemini-api-key"
export TF_VAR_grafana_admin_password="your-grafana-password"
export TF_VAR_mlflow_db_password="your-mlflow-db-password"
export TF_VAR_airflow_db_password="your-airflow-db-password"
export TF_VAR_airflow_fernet_key="your-fernet-key"
export TF_VAR_airflow_secret_key="your-secret-key"
```

### **2. Deploy Infrastructure**

```bash
cd terraform

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

### **3. Access Your MLOps Platform**

After deployment, you'll have access to:

```bash
# Get URLs
terraform output airflow_url    # Airflow UI
terraform output mlflow_url     # MLflow UI
terraform output grafana_url    # Monitoring
terraform output load_balancer_url  # Main app
```

## 📊 **MLOps Dashboard URLs**

### **Airflow (Workflow Orchestration)**
- **URL**: `http://your-alb-url:8080`
- **Login**: admin / admin (default)
- **Purpose**: 
  - Schedule and monitor ML pipelines
  - View DAG execution status
  - Manage workflow dependencies

### **MLflow (Model Management)**
- **URL**: `http://your-alb-url:5000`
- **Purpose**:
  - Track experiments and metrics
  - Version and register models
  - Compare model performance
  - Manage model lifecycle

### **Grafana (Monitoring)**
- **URL**: `http://your-alb-url:3000`
- **Login**: admin / your-grafana-password
- **Purpose**:
  - Monitor infrastructure metrics
  - Track application performance
  - Set up alerts and notifications

## 🔄 **YOLO Training Pipeline**

### **Pipeline Stages**

1. **Data Preparation**
   - Validate dataset structure
   - Log dataset metadata to MLflow
   - Prepare training/validation splits

2. **Model Training**
   - Train YOLO model with hyperparameters
   - Log training metrics and artifacts
   - Save model checkpoints

3. **Model Evaluation**
   - Run validation on test dataset
   - Calculate performance metrics (mAP, precision, recall)
   - Log evaluation results

4. **Model Registration**
   - Register model in MLflow Model Registry
   - Version the model automatically
   - Tag with metadata and quality metrics

5. **A/B Testing**
   - Compare new model with production model
   - Statistical significance testing
   - Performance improvement analysis

6. **Production Promotion**
   - Automated promotion based on A/B test results
   - Archive previous production model
   - Update model serving endpoint

7. **Notification**
   - Send completion notifications
   - Update dashboards
   - Trigger deployment webhooks

### **Pipeline Configuration**

The pipeline is defined in `airflow_dags/yolo_training_pipeline.py` with:

- **Schedule**: Weekly execution (`@weekly`)
- **Retries**: 1 retry with 5-minute delay
- **Monitoring**: Full logging and metric tracking
- **Quality Gates**: Automated quality checks

## 📈 **Model Versioning Strategy**

### **MLflow Model Stages**

1. **None**: Newly registered models
2. **Staging**: Models passing quality checks
3. **Production**: Models deployed to production
4. **Archived**: Previous production models

### **Promotion Criteria**

Models are promoted to production if:
- Model quality is "good" (mAP50 > 0.7)
- Significant improvement over current production model (>5%)
- Minimum acceptable performance (mAP50 > 0.6)

## 🧪 **A/B Testing Framework**

### **Comparison Metrics**
- **mAP50**: Mean Average Precision at IoU=0.5
- **mAP50-95**: Mean Average Precision at IoU=0.5:0.95
- **Precision**: True positives / (True positives + False positives)
- **Recall**: True positives / (True positives + False negatives)
- **F1 Score**: Harmonic mean of precision and recall

### **Statistical Significance**
- Minimum improvement threshold: 5%
- Confidence level: 95%
- Sample size validation

## 🔧 **Customizing the Pipeline**

### **Dataset Configuration**

Update the dataset preparation function in `yolo_training_pipeline.py`:

```python
def prepare_dataset(**context):
    dataset_info = {
        'train_images': your_train_count,
        'val_images': your_val_count,
        'test_images': your_test_count,
        'classes': ['your', 'class', 'names'],
        'data_path': '/path/to/your/dataset'
    }
    # ... rest of the function
```

### **Training Parameters**

Modify training parameters in the `train_yolo_model` function:

```python
training_params = {
    'model_size': 'yolov8s',  # n, s, m, l, x
    'epochs': 100,
    'batch_size': 32,
    'image_size': 640,
    'learning_rate': 0.01,
    'device': 'cuda' if torch.cuda.is_available() else 'cpu'
}
```

### **Quality Thresholds**

Adjust quality thresholds in the evaluation function:

```python
model_quality = "good" if evaluation_metrics['map50'] > 0.8 else "needs_improvement"
```

## 📊 **Monitoring and Alerts**

### **Key Metrics to Monitor**

1. **Training Metrics**
   - Training loss progression
   - Validation accuracy
   - Training time per epoch

2. **Model Performance**
   - mAP scores across classes
   - Precision/Recall curves
   - Confusion matrices

3. **Infrastructure Metrics**
   - CPU/GPU utilization
   - Memory usage
   - Storage consumption

4. **Pipeline Health**
   - DAG success rates
   - Task execution times
   - Error frequencies

### **Setting Up Alerts**

Configure Grafana alerts for:
- Pipeline failures
- Model performance degradation
- Infrastructure resource limits
- Data drift detection

## 🚨 **Troubleshooting**

### **Common Issues**

1. **Airflow Tasks Failing**
   ```bash
   # Check Airflow logs
   docker logs <airflow-container-id>
   
   # Check task logs in Airflow UI
   # Navigate to DAG → Task → Logs
   ```

2. **MLflow Connection Issues**
   ```bash
   # Verify MLflow server is running
   curl http://your-alb-url:5000/health
   
   # Check database connectivity
   # Verify PostgreSQL is accessible
   ```

3. **Model Training Failures**
   ```bash
   # Check GPU availability
   nvidia-smi
   
   # Verify dataset paths
   ls -la /opt/airflow/data/
   
   # Check disk space
   df -h
   ```

### **Debugging Commands**

```bash
# Check ECS services
aws ecs describe-services --cluster greenai-cluster

# View logs
aws logs tail /ecs/greenai-airflow --follow
aws logs tail /ecs/greenai-mlflow --follow

# Check database status
aws rds describe-db-instances --db-instance-identifier greenai-airflow-db
```

## 🎯 **Next Steps**

1. **Deploy the Infrastructure**
   ```bash
   terraform apply
   ```

2. **Upload Your Dataset**
   - Prepare your crop disease dataset
   - Upload to EFS or S3
   - Update dataset paths in the DAG

3. **Customize the Pipeline**
   - Modify training parameters
   - Adjust quality thresholds
   - Add custom evaluation metrics

4. **Set Up Monitoring**
   - Configure Grafana dashboards
   - Set up alert notifications
   - Monitor pipeline execution

5. **Run Your First Training**
   - Trigger the DAG manually
   - Monitor execution in Airflow UI
   - Check results in MLflow

## 🎉 **Benefits of This MLOps Setup**

- ✅ **Automated Training**: Scheduled model retraining
- ✅ **Version Control**: Complete model lineage tracking
- ✅ **Quality Assurance**: Automated testing and validation
- ✅ **A/B Testing**: Data-driven model promotion
- ✅ **Monitoring**: Full observability of ML pipeline
- ✅ **Scalability**: Cloud-native, auto-scaling infrastructure
- ✅ **Reproducibility**: Containerized, version-controlled pipeline

Your GreenAI application now has enterprise-grade MLOps capabilities! 🚀🤖