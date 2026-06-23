terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}



# Part 3 additions

data "azurerm_arc_machine" "vm" {
  name                = "vm-infra-01"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_arc_machine_extension" "ama" {
  name                       = "AzureMonitorWindowsAgent"
  location                   = azurerm_resource_group.main.location
  arc_machine_id             = data.azurerm_arc_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
}

resource "azurerm_monitor_data_collection_rule" "main" {
  name                = "dcr-infra-lab"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "law-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Event", "Microsoft-Perf"]
    destinations = ["law-destination"]
  }

  data_sources {
    windows_event_log {
      streams        = ["Microsoft-Event"]
      x_path_queries = [
        "Security!*[System[(EventID=4624 or EventID=4625)]]",
        "System!*[System[(Level=1 or Level=2 or Level=3)]]"
      ]
      name = "windowsEventLogs"
    }

    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\LogicalDisk(_Total)\\% Free Space"
      ]
      name = "performanceCounters"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "main" {
  name                    = "dcra-infra-vm"
  target_resource_id      = data.azurerm_arc_machine.vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.main.id
}



# Part 4 additions

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-infra-lab"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "infralab"

  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}
/*
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "failed_logins" {
  name                 = "alert-failed-logins"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 2
  enabled              = true

  criteria {
    query                   = "SecurityEvent | where EventID == 4625 | summarize FailedAttempts = count() by Computer | where FailedAttempts > 5"
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }
}
*/
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_cpu" {
  name                 = "alert-high-cpu"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 2
  enabled              = true

  criteria {
    query                   = "Perf | where ObjectName == 'Processor' and CounterName == '% Processor Time' and InstanceName == '_Total' and CounterValue > 90 | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)"
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "low_disk" {
  name                 = "alert-low-disk"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  evaluation_frequency = "PT15M"
  window_duration      = "PT15M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 2
  enabled              = true

  criteria {
    query                   = "Perf | where ObjectName == 'LogicalDisk' and CounterName == '% Free Space' and InstanceName == '_Total' and CounterValue < 20"
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }
}
