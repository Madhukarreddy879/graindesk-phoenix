import Chart from "chart.js/auto"

const BarChartHook = {
  mounted() {
    const ctx = this.el.getContext("2d")
    const data = JSON.parse(this.el.dataset.chartData)
    
    this.chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [{
          label: data.label || "Data",
          data: data.values,
          backgroundColor: data.backgroundColor || [
            "rgba(255, 99, 132, 0.8)",
            "rgba(54, 162, 235, 0.8)",
            "rgba(255, 206, 86, 0.8)",
            "rgba(75, 192, 192, 0.8)",
            "rgba(153, 102, 255, 0.8)"
          ],
          borderColor: data.borderColor || [
            "rgba(255, 99, 132, 1)",
            "rgba(54, 162, 235, 1)",
            "rgba(255, 206, 86, 1)",
            "rgba(75, 192, 192, 1)",
            "rgba(153, 102, 255, 1)"
          ],
          borderWidth: 1
        }]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: "top"
          },
          tooltip: {
            enabled: true
          }
        },
        scales: {
          x: {
            beginAtZero: true
          }
        }
      }
    })
  },

  updated() {
    const data = JSON.parse(this.el.dataset.chartData)
    
    if (this.chart) {
      this.chart.data.labels = data.labels
      this.chart.data.datasets[0].data = data.values
      this.chart.data.datasets[0].label = data.label || "Data"
      
      if (data.backgroundColor) {
        this.chart.data.datasets[0].backgroundColor = data.backgroundColor
      }
      if (data.borderColor) {
        this.chart.data.datasets[0].borderColor = data.borderColor
      }
      
      this.chart.update()
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}

export default BarChartHook
