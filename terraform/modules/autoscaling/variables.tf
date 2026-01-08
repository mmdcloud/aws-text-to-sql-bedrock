variable "max_capacity" {}
variable "min_capacity" {}
variable "resource_id" {}
variable "scalable_dimension" {}
variable "service_namespace" {}
variable "policies" {
  description = "List of auto scaling policies with their configurations"
  type = list(object({
    name        = string
    policy_type = string # "StepScaling", "TargetTrackingScaling", or "PredictiveScaling"
    
    # Step Scaling Policy Configuration
    step_scaling_policy_configuration = optional(object({
      adjustment_type          = optional(string)  # "ChangeInCapacity", "ExactCapacity", or "PercentChangeInCapacity"
      cooldown                 = optional(number)  # Cooldown period in seconds
      metric_aggregation_type  = optional(string)  # "Average", "Maximum", or "Minimum"
      min_adjustment_magnitude = optional(number)  # Minimum number of instances to scale
      
      step_adjustment = optional(list(object({
        metric_interval_lower_bound = optional(number)
        metric_interval_upper_bound = optional(number)
        scaling_adjustment          = number
      })))
    }))
    
    # Predictive Scaling Policy Configuration
    predictive_scaling_policy_configuration = optional(object({
      max_capacity_buffer          = optional(number)  # 0-100, buffer above predicted capacity
      mode                         = optional(string)  # "ForecastAndScale" or "ForecastOnly"
      scheduling_buffer_time       = optional(number)  # Time buffer in seconds
      max_capacity_breach_behavior = optional(string)  # "HonorMaxCapacity" or "IncreaseMaxCapacity"
      
      metric_specification = optional(object({
        target_value = number
        
        # Customized Capacity Metric
        customized_capacity_metric_specification = optional(object({
          metric_data_query = list(object({
            id          = string
            expression  = optional(string)
            label       = optional(string)
            return_data = optional(bool)
            
            metric_stat = optional(object({
              stat = string  # "Average", "Sum", "Maximum", "Minimum", "SampleCount"
              unit = optional(string)
              
              metric = optional(object({
                metric_name = string
                namespace   = string
                dimension = optional(list(object({
                  name  = string
                  value = string
                })))
              }))
            }))
          }))
        }))
        
        # Customized Load Metric
        customized_load_metric_specification = optional(object({
          metric_data_query = list(object({
            id          = string
            expression  = optional(string)
            label       = optional(string)
            return_data = optional(bool)
            
            metric_stat = optional(object({
              stat = string
              unit = optional(string)
              
              metric = optional(object({
                metric_name = string
                namespace   = string
                dimension = optional(list(object({
                  name  = string
                  value = string
                })))
              }))
            }))
          }))
        }))
        
        # Customized Scaling Metric
        customized_scaling_metric_specification = optional(object({
          metric_data_query = list(object({
            id          = string
            expression  = optional(string)
            label       = optional(string)
            return_data = optional(bool)
            
            metric_stat = optional(object({
              stat = string
              unit = optional(string)
              
              metric = optional(object({
                metric_name = string
                namespace   = string
                dimension = optional(list(object({
                  name  = string
                  value = string
                })))
              }))
            }))
          }))
        }))
        
        # Predefined Metric Pair
        predefined_metric_pair_specification = optional(object({
          predefined_metric_type = string  # "ECSServiceAverageCPUUtilization", "ECSServiceAverageMemoryUtilization", etc.
          resource_label         = optional(string)
        }))
        
        # Predefined Load Metric
        predefined_load_metric_specification = optional(object({
          predefined_metric_type = string
          resource_label         = optional(string)
        }))
        
        # Predefined Scaling Metric
        predefined_scaling_metric_specification = optional(object({
          predefined_metric_type = string
          resource_label         = optional(string)
        }))
      }))
    }))
    
    # Target Tracking Scaling Policy Configuration
    target_tracking_scaling_policy_configuration = optional(object({
      target_value       = number
      disable_scale_in   = optional(bool, false)
      scale_in_cooldown  = optional(number)  # Cooldown period for scale in (seconds)
      scale_out_cooldown = optional(number)  # Cooldown period for scale out (seconds)
      
      # Customized Metric Specification
      customized_metric_specification = optional(object({
        metric_name = optional(string)
        namespace   = optional(string)
        statistic   = optional(string)  # "Average", "Sum", "Maximum", "Minimum", "SampleCount"
        unit        = optional(string)
        
        metrics = optional(list(object({
          id          = string
          expression  = optional(string)
          label       = optional(string)
          return_data = optional(bool)
          
          metric_stat = optional(object({
            stat = string
            unit = optional(string)
            
            metric = optional(object({
              metric_name = string
              namespace   = string
              dimension = optional(list(object({
                name  = string
                value = string
              })))
            }))
          }))
        })))
        
        dimension = optional(list(object({
          name  = string
          value = string
        })))
      }))
      
      # Predefined Metric Specification
      predefined_metric_specification = optional(object({
        predefined_metric_type = string  # "ECSServiceAverageCPUUtilization", "ECSServiceAverageMemoryUtilization", etc.
        resource_label         = optional(string)
      }))
    }))
  }))
  
  default = []
}