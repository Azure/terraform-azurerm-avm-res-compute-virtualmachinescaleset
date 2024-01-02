# create autoscale resource that will decrease the number of instances if the azurerm_orchestrated_scale set cpu usaae is below 10% for 2 minutes
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  target_resource_id  = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource_id
  enabled             = true
  predictive {
    scale_mode      = "Enabled"
    look_ahead_time = "PT5M"
  }
  profile {
    name = "autoscale"
    capacity {
      default = 2
      minimum = 1
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource_id
        operator           = "LessThan"
        statistic          = "Average"
        time_aggregation   = "Average"
        time_window        = "PT2M"
        time_grain         = "PT1M"
        threshold          = 10
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource_id
        operator           = "GreaterThan"
        statistic          = "Average"
        time_aggregation   = "Average"
        time_window        = "PT2M"
        time_grain         = "PT1M"
        threshold          = 90
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}
