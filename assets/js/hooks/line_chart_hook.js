import Chart from "chart.js/auto"

const LineChartHook = {
  mounted() {
    const ctx = this.el.getContext("2d")
    const data = JSON.parse(this.el.dataset.chartData)
    
    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: data.labels,
        datasets: [{
          label: data.label || "Data",
          data: data.values,
          borderColor: data.borderColor || "rgb(75, 192, 192)",
          backgroundColor: data.backgroundColor || "rgba(75, 192, 192, 0.2)",
          tension: 0.1,
          fill: true
        }]
      },
      options: {
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
          y: {
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
      this.chart.data.datasets[0].borderColor = data.borderColor || "rgb(75, 192, 192)"
      this.chart.data.datasets[0].backgroundColor = data.backgroundColor || "rgba(75, 192, 192, 0.2)"
      this.chart.update()
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}

export default LineChartHook
