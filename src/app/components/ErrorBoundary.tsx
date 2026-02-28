import { useRouteError, useNavigate } from "react-router";
import { AlertCircle, Home } from "lucide-react";

export function ErrorBoundary() {
  const error = useRouteError() as Error;
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-lg shadow-md p-8 text-center">
        <div className="flex justify-center mb-4">
          <div className="bg-red-100 rounded-full p-3">
            <AlertCircle className="text-red-600" size={32} />
          </div>
        </div>
        
        <h1 className="text-2xl font-bold text-gray-900 mb-2">
          Algo salió mal
        </h1>
        
        <p className="text-gray-600 mb-6">
          {error?.message || "Ha ocurrido un error inesperado"}
        </p>
        
        <div className="space-y-3">
          <button
            onClick={() => navigate("/")}
            className="w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-lg transition-colors"
          >
            <Home size={20} />
            Volver al inicio
          </button>
          
          <button
            onClick={() => window.location.reload()}
            className="w-full bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-3 rounded-lg transition-colors"
          >
            Recargar página
          </button>
        </div>
        
        {process.env.NODE_ENV === 'development' && error && (
          <details className="mt-6 text-left">
            <summary className="text-sm text-gray-500 cursor-pointer hover:text-gray-700">
              Detalles técnicos
            </summary>
            <pre className="mt-2 p-3 bg-gray-100 rounded text-xs overflow-auto">
              {error.stack || error.toString()}
            </pre>
          </details>
        )}
      </div>
    </div>
  );
}
