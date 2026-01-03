# App Auto Scaling Target
resource "aws_appautoscaling_target" "target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = var.resource_id
  scalable_dimension = var.scalable_dimension
  service_namespace  = var.service_namespace
}

# App Auto Scaling Policy
resource "aws_appautoscaling_policy" "policy" {
  count              = length(var.policies)
  name               = var.policies[count.index].name
  policy_type        = var.policies[count.index].policy_type
  resource_id        = aws_appautoscaling_target.target.resource_id
  scalable_dimension = aws_appautoscaling_target.target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.target.service_namespace
  dynamic "step_scaling_policy_configuration" {
    for_each = var.policies[count.index].step_scaling_policy_configuration != null ? [var.policies[count.index].step_scaling_policy_configuration] : []
    content {
      adjustment_type          = each.value.adjustment_type
      cooldown                 = each.value.cooldown
      metric_aggregation_type  = each.value.metric_aggregation_type
      min_adjustment_magnitude = each.value.min_adjustment_magnitude
      dynamic "step_adjustment" {
        for_each = each.value.step_adjustment
        content {
          metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
          metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
          scaling_adjustment          = step_adjustment.value.scaling_adjustment
        }
      }
    }
  }
  dynamic "predictive_scaling_policy_configuration" {
    for_each = var.policies[count.index].predictive_scaling_policy_configuration != null ? [var.policies[count.index].predictive_scaling_policy_configuration] : []
    content {
      dynamic "metric_specification" {
        for_each = predictive_scaling_policy_configuration.value.metric_specification != null ? [predictive_scaling_policy_configuration.value.metric_specification] : []
        content {
          target_value = metric_specification.value.target_value
          dynamic "customized_capacity_metric_specification" {
            for_each = metric_specification.value.customized_capacity_metric_specification != null ? [metric_specification.value.customized_capacity_metric_specification] : []
            content {
              dynamic "metric_data_query" {
                for_each = customized_capacity_metric_specification.value.metric_data_query
                content {
                  id          = metric_data_query.value.id
                  expression  = metric_data_query.value.expression
                  label       = metric_data_query.value.label
                  return_data = metric_data_query.value.return_data
                  dynamic "metric_stat" {
                    for_each = metric_data_query.value.metric_stat != null ? [metric_data_query.value.metric_stat] : []
                    content {
                      stat = metric_stat.value.stat
                      unit = metric_stat.value.unit
                      dynamic "metric" {
                        for_each = metric_stat.value.metric != null ? [metric_stat.value.metric] : []
                        content {
                          metric_name = metric.value.metric_name
                          namespace   = metric.value.namespace
                          dynamic "dimensions" {
                            for_each = metric.value.dimension
                            content {
                              name  = dimensions.value.name
                              value = dimensions.value.value
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          dynamic "customized_load_metric_specification" {
            for_each = metric_specification.value.customized_load_metric_specification != null ? [metric_specification.value.customized_load_metric_specification] : []
            content {
              dynamic "metric_data_query" {
                for_each = customized_load_metric_specification.value.metric_data_query
                content {
                  id          = metric_data_query.value.id
                  expression  = metric_data_query.value.expression
                  label       = metric_data_query.value.label
                  return_data = metric_data_query.value.return_data
                  dynamic "metric_stat" {
                    for_each = metric_data_query.value.metric_stat != null ? [metric_data_query.value.metric_stat] : []
                    content {
                      stat = metric_stat.value.stat
                      unit = metric_stat.value.unit
                      dynamic "metric" {
                        for_each = metric_stat.value.metric != null ? [metric_stat.value.metric] : []
                        content {
                          metric_name = metric.value.metric_name
                          namespace   = metric.value.namespace
                          dynamic "dimensions" {
                            for_each = metric.value.dimension
                            content {
                              name  = dimensions.value.name
                              value = dimensions.value.value
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          dynamic "customized_scaling_metric_specification" {
            for_each = metric_specification.value.customized_scaling_metric_specification != null ? [metric_specification.value.customized_scaling_metric_specification] : []
            content {
              dynamic "metric_data_query" {
                for_each = customized_scaling_metric_specification.value.metric_data_query
                content {
                  id          = metric_data_query.value.id
                  expression  = metric_data_query.value.expression
                  label       = metric_data_query.value.label
                  return_data = metric_data_query.value.return_data
                  dynamic "metric_stat" {
                    for_each = metric_data_query.value.metric_stat != null ? [metric_data_query.value.metric_stat] : []
                    content {
                      stat = metric_stat.value.stat
                      unit = metric_stat.value.unit
                      dynamic "metric" {
                        for_each = metric_stat.value.metric != null ? [metric_stat.value.metric] : []
                        content {
                          metric_name = metric.value.metric_name
                          namespace   = metric.value.namespace
                          dynamic "dimensions" {
                            for_each = metric.value.dimension
                            content {
                              name  = dimensions.value.name
                              value = dimensions.value.value
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          dynamic "predefined_metric_pair_specification" {
            for_each = metric_specification.value.predefined_metric_pair_specification != null ? [metric_specification.value.predefined_metric_pair_specification] : []
            content {
              predefined_metric_type = predefined_metric_pair_specification.value.predefined_metric_type
              resource_label         = predefined_metric_pair_specification.value.resource_label
            }
          }
          dynamic "predefined_load_metric_specification" {
            for_each = metric_specification.value.predefined_load_metric_specification != null ? [metric_specification.value.predefined_load_metric_specification] : []
            content {
              predefined_metric_type = predefined_load_metric_specification.value.predefined_metric_type
              resource_label         = predefined_load_metric_specification.value.resource_label
            }
          }
          dynamic "predefined_scaling_metric_specification" {
            for_each = metric_specification.value.predefined_scaling_metric_specification != null ? [metric_specification.value.predefined_scaling_metric_specification] : []
            content {
              predefined_metric_type = predefined_scaling_metric_specification.value.predefined_metric_type
              resource_label         = predefined_scaling_metric_specification.value.resource_label
            }
          }
        }
      }
      max_capacity_buffer          = predictive_scaling_policy_configuration.value.max_capacity_buffer
      mode                         = predictive_scaling_policy_configuration.value.mode
      scheduling_buffer_time       = predictive_scaling_policy_configuration.value.scheduling_buffer_time
      max_capacity_breach_behavior = predictive_scaling_policy_configuration.value.max_capacity_breach_behavior
    }
  }
  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = var.policies[count.index].target_tracking_scaling_policy_configuration != null ? [var.policies[count.index].target_tracking_scaling_policy_configuration] : []
    content {
      dynamic "customized_metric_specification" {
        for_each = target_tracking_scaling_policy_configuration.value.customized_metric_specification != null ? [target_tracking_scaling_policy_configuration.value.customized_metric_specification] : []
        content {
          metric_name = customized_metric_specification.value.metric_name
          namespace   = customized_metric_specification.value.namespace
          statistic   = customized_metric_specification.value.statistic
          unit        = customized_metric_specification.value.unit
          dynamic "metrics" {
            for_each = customized_metric_specification.value.metrics
            content {
              id          = metrics.value.id
              expression  = metrics.value.expression
              label       = metrics.value.label
              return_data = metrics.value.return_data
              dynamic "metric_stat" {
                for_each = metrics.value.metric_stat != null ? [metrics.value.metric_stat] : []
                content {
                  stat = metric_stat.value.stat
                  unit = metric_stat.value.unit
                  dynamic "metric" {
                    for_each = metric_stat.value.metric != null ? [metric_stat.value.metric] : []
                    content {
                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                      dynamic "dimensions" {
                        for_each = metric.value.dimension
                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }
                    }

                  }
                }

              }
            }
          }
          dynamic "dimensions" {
            for_each = customized_metric_specification.value.dimension
            content {
              name  = dimension.value.name
              value = dimension.value.value
            }
          }
        }
      }
      dynamic "predefined_metric_specification" {
        for_each = target_tracking_scaling_policy_configuration.value.predefined_metric_specification != null ? [target_tracking_scaling_policy_configuration.value.predefined_metric_specification] : []
        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label         = predefined_metric_specification.value.resource_label
        }
      }
      disable_scale_in   = target_tracking_scaling_policy_configuration.value.disable_scale_in
      target_value       = target_tracking_scaling_policy_configuration.value.target_value
      scale_in_cooldown  = target_tracking_scaling_policy_configuration.value.scale_in_cooldown
      scale_out_cooldown = target_tracking_scaling_policy_configuration.value.scale_out_cooldown
    }
  }
}