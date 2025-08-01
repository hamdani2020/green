"""
YOLO Model Training Pipeline for GreenAI
This DAG orchestrates the complete MLOps pipeline for YOLO model training,
evaluation, versioning, and deployment using MLflow.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.amazon.aws.operators.s3 import S3CreateBucketOperator
import mlflow
import mlflow.pytorch
import boto3
import os
import json
import requests
from ultralytics import YOLO
import torch
import numpy as np
from sklearn.metrics import precision_score, recall_score, f1_score

# Default arguments for the DAG
default_args = {
    'owner': 'greenai-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# DAG definition
dag = DAG(
    'yolo_training_pipeline',
    default_args=default_args,
    description='Complete YOLO model training and deployment pipeline',
    schedule_interval='@weekly',  # Run weekly
    catchup=False,
    tags=['ml', 'yolo', 'computer-vision', 'greenai'],
)

# MLflow configuration
MLFLOW_TRACKING_URI = os.getenv('MLFLOW_TRACKING_URI', 'http://mlflow:5000')
EXPERIMENT_NAME = "greenai-yolo-training"
MODEL_NAME = "greenai-yolo-model"

def setup_mlflow():
    """Setup MLflow tracking and experiment"""
    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    
    # Create experiment if it doesn't exist
    try:
        experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
        if experiment is None:
            mlflow.create_experiment(EXPERIMENT_NAME)
    except Exception as e:
        print(f"Error setting up experiment: {e}")
        mlflow.create_experiment(EXPERIMENT_NAME)
    
    mlflow.set_experiment(EXPERIMENT_NAME)

def prepare_dataset(**context):
    """
    Prepare and validate the dataset for training
    This function should be customized based on your specific dataset
    """
    print("🔄 Preparing dataset for YOLO training...")
    
    # Example dataset preparation - customize this for your crop disease dataset
    dataset_info = {
        'train_images': 1000,
        'val_images': 200,
        'test_images': 100,
        'classes': ['healthy', 'diseased', 'pest_damage', 'nutrient_deficiency'],
        'dataset_version': '1.0',
        'data_path': '/opt/airflow/data/crop_disease_dataset'
    }
    
    # Log dataset info to MLflow
    setup_mlflow()
    with mlflow.start_run(run_name="dataset_preparation"):
        mlflow.log_params(dataset_info)
        mlflow.log_metric("total_images", dataset_info['train_images'] + dataset_info['val_images'] + dataset_info['test_images'])
    
    # Store dataset info for next tasks
    context['task_instance'].xcom_push(key='dataset_info', value=dataset_info)
    
    print("✅ Dataset preparation completed")
    return dataset_info

def train_yolo_model(**context):
    """
    Train YOLO model with the prepared dataset
    """
    print("🚀 Starting YOLO model training...")
    
    # Get dataset info from previous task
    dataset_info = context['task_instance'].xcom_pull(key='dataset_info', task_ids='prepare_dataset')
    
    setup_mlflow()
    
    with mlflow.start_run(run_name="yolo_training") as run:
        # Training parameters
        training_params = {
            'model_size': 'yolov8n',  # nano model for faster training
            'epochs': 50,
            'batch_size': 16,
            'image_size': 640,
            'learning_rate': 0.01,
            'optimizer': 'SGD',
            'augmentation': True,
            'device': 'cpu'  # Use GPU if available
        }
        
        # Log training parameters
        mlflow.log_params(training_params)
        mlflow.log_params(dataset_info)
        
        try:
            # Initialize YOLO model
            model = YOLO('yolov8n.pt')  # Start with pre-trained weights
            
            # Training configuration
            train_config = {
                'data': '/opt/airflow/data/dataset.yaml',  # Your dataset config
                'epochs': training_params['epochs'],
                'batch': training_params['batch_size'],
                'imgsz': training_params['image_size'],
                'lr0': training_params['learning_rate'],
                'device': training_params['device'],
                'project': '/opt/airflow/runs',
                'name': f'yolo_training_{run.info.run_id}',
                'save_period': 10,  # Save checkpoint every 10 epochs
            }
            
            # Train the model
            print("🔥 Training YOLO model...")
            results = model.train(**train_config)
            
            # Log training metrics
            if hasattr(results, 'results_dict'):
                metrics = results.results_dict
                for key, value in metrics.items():
                    if isinstance(value, (int, float)):
                        mlflow.log_metric(key, value)
            
            # Save model artifacts
            model_path = f"/opt/airflow/runs/yolo_training_{run.info.run_id}/weights/best.pt"
            
            # Log model to MLflow
            mlflow.pytorch.log_model(
                pytorch_model=model.model,
                artifact_path="model",
                registered_model_name=MODEL_NAME
            )
            
            # Log additional artifacts
            mlflow.log_artifact(model_path, "model_weights")
            
            # Store model info for next tasks
            model_info = {
                'run_id': run.info.run_id,
                'model_path': model_path,
                'model_version': None,  # Will be set after registration
                'training_metrics': metrics if 'metrics' in locals() else {}
            }
            
            context['task_instance'].xcom_push(key='model_info', value=model_info)
            
            print("✅ YOLO model training completed successfully")
            return model_info
            
        except Exception as e:
            mlflow.log_param("training_status", "failed")
            mlflow.log_param("error_message", str(e))
            print(f"❌ Training failed: {e}")
            raise

def evaluate_model(**context):
    """
    Evaluate the trained model and log metrics
    """
    print("📊 Evaluating trained YOLO model...")
    
    model_info = context['task_instance'].xcom_pull(key='model_info', task_ids='train_yolo_model')
    
    setup_mlflow()
    
    with mlflow.start_run(run_id=model_info['run_id']):
        try:
            # Load the trained model
            model = YOLO(model_info['model_path'])
            
            # Run validation
            print("🔍 Running model validation...")
            val_results = model.val(data='/opt/airflow/data/dataset.yaml')
            
            # Extract evaluation metrics
            evaluation_metrics = {
                'map50': val_results.box.map50,  # mAP at IoU=0.5
                'map50_95': val_results.box.map,  # mAP at IoU=0.5:0.95
                'precision': val_results.box.mp,  # Mean precision
                'recall': val_results.box.mr,     # Mean recall
                'f1_score': 2 * (val_results.box.mp * val_results.box.mr) / (val_results.box.mp + val_results.box.mr)
            }
            
            # Log evaluation metrics
            for metric_name, metric_value in evaluation_metrics.items():
                mlflow.log_metric(f"eval_{metric_name}", float(metric_value))
            
            # Model quality assessment
            model_quality = "good" if evaluation_metrics['map50'] > 0.7 else "needs_improvement"
            mlflow.log_param("model_quality", model_quality)
            
            # Store evaluation results
            model_info['evaluation_metrics'] = evaluation_metrics
            model_info['model_quality'] = model_quality
            
            context['task_instance'].xcom_push(key='model_info', value=model_info)
            
            print(f"✅ Model evaluation completed. Quality: {model_quality}")
            print(f"📈 Key metrics - mAP50: {evaluation_metrics['map50']:.3f}, Precision: {evaluation_metrics['precision']:.3f}")
            
            return evaluation_metrics
            
        except Exception as e:
            mlflow.log_param("evaluation_status", "failed")
            mlflow.log_param("error_message", str(e))
            print(f"❌ Evaluation failed: {e}")
            raise

def register_model(**context):
    """
    Register the model in MLflow Model Registry with versioning
    """
    print("📝 Registering model in MLflow Model Registry...")
    
    model_info = context['task_instance'].xcom_pull(key='model_info', task_ids='evaluate_model')
    
    setup_mlflow()
    
    try:
        # Get the model from the run
        model_uri = f"runs:/{model_info['run_id']}/model"
        
        # Register model version
        model_version = mlflow.register_model(
            model_uri=model_uri,
            name=MODEL_NAME,
            description=f"YOLO model for crop disease detection - Quality: {model_info['model_quality']}"
        )
        
        # Add model version info
        model_info['model_version'] = model_version.version
        
        # Set model stage based on quality
        client = mlflow.tracking.MlflowClient()
        
        if model_info['model_quality'] == "good":
            # Transition to Staging for further testing
            client.transition_model_version_stage(
                name=MODEL_NAME,
                version=model_version.version,
                stage="Staging",
                archive_existing_versions=False
            )
            
            # Add tags
            client.set_model_version_tag(
                name=MODEL_NAME,
                version=model_version.version,
                key="quality",
                value=model_info['model_quality']
            )
            
            client.set_model_version_tag(
                name=MODEL_NAME,
                version=model_version.version,
                key="training_date",
                value=datetime.now().isoformat()
            )
            
            print(f"✅ Model version {model_version.version} registered and moved to Staging")
        else:
            print(f"⚠️ Model version {model_version.version} registered but kept in None stage due to quality issues")
        
        context['task_instance'].xcom_push(key='model_info', value=model_info)
        
        return model_version.version
        
    except Exception as e:
        print(f"❌ Model registration failed: {e}")
        raise

def run_ab_test(**context):
    """
    Run A/B test comparing new model with current production model
    """
    print("🧪 Running A/B test for model comparison...")
    
    model_info = context['task_instance'].xcom_pull(key='model_info', task_ids='register_model')
    
    setup_mlflow()
    
    try:
        client = mlflow.tracking.MlflowClient()
        
        # Get current production model (if any)
        try:
            prod_model = client.get_latest_versions(MODEL_NAME, stages=["Production"])[0]
            print(f"🔄 Comparing with production model version {prod_model.version}")
            
            # Load both models for comparison
            new_model_uri = f"models:/{MODEL_NAME}/{model_info['model_version']}"
            prod_model_uri = f"models:/{MODEL_NAME}/{prod_model.version}"
            
            # Run comparison on test dataset
            # This is a simplified comparison - implement your specific A/B testing logic
            new_model_score = model_info['evaluation_metrics']['map50']
            
            # Get production model metrics (stored in model version tags or run metrics)
            prod_run_id = prod_model.run_id
            prod_run = mlflow.get_run(prod_run_id)
            prod_model_score = prod_run.data.metrics.get('eval_map50', 0.0)
            
            # Compare models
            improvement = new_model_score - prod_model_score
            improvement_threshold = 0.05  # 5% improvement threshold
            
            ab_test_results = {
                'new_model_version': model_info['model_version'],
                'prod_model_version': prod_model.version,
                'new_model_score': new_model_score,
                'prod_model_score': prod_model_score,
                'improvement': improvement,
                'significant_improvement': improvement > improvement_threshold
            }
            
            # Log A/B test results
            with mlflow.start_run(run_name="ab_test_results"):
                mlflow.log_params(ab_test_results)
            
            print(f"📊 A/B Test Results:")
            print(f"   New Model (v{model_info['model_version']}): {new_model_score:.3f}")
            print(f"   Prod Model (v{prod_model.version}): {prod_model_score:.3f}")
            print(f"   Improvement: {improvement:.3f} ({'Significant' if ab_test_results['significant_improvement'] else 'Not significant'})")
            
        except IndexError:
            print("ℹ️ No production model found. This will be the first production model.")
            ab_test_results = {
                'new_model_version': model_info['model_version'],
                'prod_model_version': None,
                'new_model_score': model_info['evaluation_metrics']['map50'],
                'prod_model_score': 0.0,
                'improvement': model_info['evaluation_metrics']['map50'],
                'significant_improvement': True  # First model is always significant
            }
        
        model_info['ab_test_results'] = ab_test_results
        context['task_instance'].xcom_push(key='model_info', value=model_info)
        
        return ab_test_results
        
    except Exception as e:
        print(f"❌ A/B test failed: {e}")
        raise

def promote_to_production(**context):
    """
    Promote model to production based on A/B test results
    """
    print("🚀 Evaluating model for production promotion...")
    
    model_info = context['task_instance'].xcom_pull(key='model_info', task_ids='run_ab_test')
    
    setup_mlflow()
    
    try:
        client = mlflow.tracking.MlflowClient()
        ab_results = model_info['ab_test_results']
        
        # Decision logic for promotion
        should_promote = (
            model_info['model_quality'] == "good" and
            ab_results['significant_improvement'] and
            ab_results['new_model_score'] > 0.6  # Minimum acceptable performance
        )
        
        if should_promote:
            # Archive current production model
            try:
                current_prod = client.get_latest_versions(MODEL_NAME, stages=["Production"])[0]
                client.transition_model_version_stage(
                    name=MODEL_NAME,
                    version=current_prod.version,
                    stage="Archived"
                )
                print(f"📦 Archived previous production model version {current_prod.version}")
            except IndexError:
                print("ℹ️ No previous production model to archive")
            
            # Promote new model to production
            client.transition_model_version_stage(
                name=MODEL_NAME,
                version=model_info['model_version'],
                stage="Production",
                archive_existing_versions=False
            )
            
            # Add production tags
            client.set_model_version_tag(
                name=MODEL_NAME,
                version=model_info['model_version'],
                key="promoted_to_production",
                value=datetime.now().isoformat()
            )
            
            client.set_model_version_tag(
                name=MODEL_NAME,
                version=model_info['model_version'],
                key="promotion_reason",
                value=f"A/B test improvement: {ab_results['improvement']:.3f}"
            )
            
            print(f"🎉 Model version {model_info['model_version']} promoted to Production!")
            
            # Trigger deployment notification (implement webhook/notification logic)
            deployment_info = {
                'model_name': MODEL_NAME,
                'model_version': model_info['model_version'],
                'promoted_at': datetime.now().isoformat(),
                'performance_metrics': model_info['evaluation_metrics']
            }
            
            # Log promotion event
            with mlflow.start_run(run_name="production_promotion"):
                mlflow.log_params(deployment_info)
            
            return "promoted"
            
        else:
            print("⚠️ Model not promoted to production:")
            print(f"   Quality: {model_info['model_quality']}")
            print(f"   Significant improvement: {ab_results['significant_improvement']}")
            print(f"   Score: {ab_results['new_model_score']:.3f}")
            
            return "not_promoted"
            
    except Exception as e:
        print(f"❌ Production promotion failed: {e}")
        raise

def notify_completion(**context):
    """
    Send notification about pipeline completion
    """
    print("📧 Sending pipeline completion notification...")
    
    model_info = context['task_instance'].xcom_pull(key='model_info', task_ids='promote_to_production')
    promotion_result = context['task_instance'].xcom_pull(task_ids='promote_to_production')
    
    # Create summary report
    summary = {
        'pipeline_date': datetime.now().isoformat(),
        'model_version': model_info['model_version'],
        'model_quality': model_info['model_quality'],
        'evaluation_metrics': model_info['evaluation_metrics'],
        'promotion_status': promotion_result,
        'mlflow_url': f"{MLFLOW_TRACKING_URI}/#/models/{MODEL_NAME}"
    }
    
    print("📊 Pipeline Summary:")
    print(f"   Model Version: {summary['model_version']}")
    print(f"   Quality: {summary['model_quality']}")
    print(f"   mAP50: {summary['evaluation_metrics']['map50']:.3f}")
    print(f"   Promotion: {summary['promotion_status']}")
    print(f"   MLflow URL: {summary['mlflow_url']}")
    
    # Here you can implement actual notification logic:
    # - Send email
    # - Post to Slack
    # - Update dashboard
    # - Trigger deployment webhook
    
    return summary

# Define task dependencies
prepare_dataset_task = PythonOperator(
    task_id='prepare_dataset',
    python_callable=prepare_dataset,
    dag=dag,
)

train_model_task = PythonOperator(
    task_id='train_yolo_model',
    python_callable=train_yolo_model,
    dag=dag,
)

evaluate_model_task = PythonOperator(
    task_id='evaluate_model',
    python_callable=evaluate_model,
    dag=dag,
)

register_model_task = PythonOperator(
    task_id='register_model',
    python_callable=register_model,
    dag=dag,
)

ab_test_task = PythonOperator(
    task_id='run_ab_test',
    python_callable=run_ab_test,
    dag=dag,
)

promote_model_task = PythonOperator(
    task_id='promote_to_production',
    python_callable=promote_to_production,
    dag=dag,
)

notify_task = PythonOperator(
    task_id='notify_completion',
    python_callable=notify_completion,
    dag=dag,
)

# Set task dependencies
prepare_dataset_task >> train_model_task >> evaluate_model_task >> register_model_task >> ab_test_task >> promote_model_task >> notify_task