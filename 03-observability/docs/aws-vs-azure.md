# AWS and Azure session comparison

| Concern | AWS | Azure |
|---|---|---|
| VM management | Systems Manager Run Command | `az vm run-command` |
| VM size | `t3.small` by default | `Standard_B1ms` by default |
| Native CPU signal | CloudWatch `AWS/EC2 CPUUtilization` | Azure Monitor `Percentage CPU` |
| Native notification | SNS email subscription | Action Group email receiver |
| Expected native timing | Basic EC2 metrics may be delayed by the five-minute period | Azure platform metrics commonly evaluate closer to one minute |
| Inbound access | Security group has no ingress rules | NSG retains default deny inbound |
| Outbound access | Public subnet public IP, no NAT Gateway | Standard public IP, no inbound rules |

Record the actual regional prices, alert timing, VM availability, email delivery, and cleanup confirmation after the live session. Do not treat this design document as evidence of a completed test.

