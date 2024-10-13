import numpy as np
from cvxopt import matrix, solvers

# Define the quadratic programming problem in standard form
# Minimize: (1/2) * x^T * P * x + q^T * x
# Subject to: A * x = b

# Example P matrix (should be symmetric and positive semi-definite)
P = matrix([[2.0, 0.5], [0.5, 1.0]])

# q vector
q = matrix([1.0, 1.0])

# A matrix for equality constraints
A = matrix([[1.0, 1.0], [1.0, -1.0]])

# b vector for equality constraints
b = matrix([1.0, 0.0])

# Solve the quadratic programming problem
solution = solvers.qp(P, q, A=A, b=b)

# The optimal solution (x values)
x_optimal = np.array(solution['x'])

print("Optimal solution:", x_optimal)
