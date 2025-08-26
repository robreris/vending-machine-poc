import React, { useState, Fragment } from "react";
import { toast } from "react-toastify";
import { Dialog, Transition } from "@headlessui/react";
import { VITE_BACKEND_HOST } from "../config";

export default function FortiFlexConfigCard({ config }) {
  const [showMenu, setShowMenu] = useState(false);
  const [cpu, setCpu] = useState(config.parameters.find(p => p.id === 1)?.value || "2");
  const [servicePack, setServicePack] = useState(config.parameters.find(p => p.id === 2)?.value || "UTP");
  const [vdom, setVdom] = useState(config.parameters.find(p => p.id === 10)?.value || "1");
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showSubmitModal, setShowSubmitModal] = useState(false);

  const handleCreateEntitlement = async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const formattedDate = tomorrow.toISOString().split("T")[0];

    try {
      const response = await fetch(`${VITE_BACKEND_HOST}/api/fortiflex/entitlements/vm/create`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({
          configId: config.id,
          count: 1,
          description: "CloudCSE MKPL VM",
          endDate: formattedDate,
          folderPath: "My Assets"
        })
      });

      if (response.ok) {
        toast.success("Entitlement created successfully!");
        setTimeout(() => window.location.href = "/fortiflex-entitlements", 1500);
      } else {
        toast.error("Failed to create entitlement.");
      }
    } catch (err) {
      toast.error("Error creating entitlement.");
      console.error(err);
    }
    setShowCreateModal(false);
  };

  const handleSubmitChanges = async () => {
    try {
      const response = await fetch(`${VITE_BACKEND_HOST}/api/fortiflex/configs/update`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({
          id: config.id,
          name: config.name,
          parameters: [
            { id: 1, value: cpu },
            { id: 2, value: servicePack },
            { id: 10, value: vdom }
          ]
        })
      });
      if (response.ok) {
        toast.success("Configuration updated successfully!");
        setTimeout(() => window.location.reload(), 1500);
      } else {
        toast.error("Failed to update configuration.");
      }
    } catch (err) {
      toast.error("Error submitting configuration.");
      console.error(err);
    }
    setShowSubmitModal(false);
    setShowMenu(false);
  };

  return (
    <div className="border rounded-lg shadow-md p-4 bg-white">
      <img
        src={`images/${config.productType?.name?.replace(/\s+/g, '-') || 'default'}.png`}
        alt={config.name || "FortiFlex Config Image"}
        className="w-full h-40 object-cover mb-2"
        onError={(e) => {
          console.error(`Failed to load image for product type: ${config.productType?.name}`);
          e.target.src = "images/FGT-VM02.png";
        }}
      />
      <h2 className="text-lg font-bold text-gray-800 mb-2">
        {config.name || "Unnamed Configuration"}
      </h2>
      <p className="text-sm text-gray-600 mb-1">
        <strong>Config ID:</strong> {config.id}
      </p>
      <p className="text-sm text-gray-600 mb-1">
        <strong>Type:</strong> {config.productType.name || "Unknown Product Type"}
      </p>
      <p className="text-sm text-gray-600 mb-1">
        <strong>Status:</strong> {config.status}
      </p>
      <p className="text-sm text-gray-600 mb-1">
        <strong>Account ID:</strong> {config.accountId}
      </p>
      <div className="mt-2">
        <strong className="text-sm text-gray-800">Parameters:</strong>
        <ul className="list-disc list-inside text-sm text-gray-600">
          {Array.isArray(config.parameters) &&
            config.parameters.map((param) => (
              <li key={param.id}>
                <strong>{param.id}:{param.name}:</strong> {param.value}
              </li>
            ))}
        </ul>
      </div>

      <div className="flex gap-2 mt-4">
        <button
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          onClick={() => setShowMenu(true)}
        >
          Modify Configuration
        </button>

        <button
          className={`px-4 py-2 text-white rounded ${
            cpu === "2" ? "bg-blue-600 hover:bg-blue-700" : "bg-gray-400 cursor-not-allowed"
          }`}
          disabled={cpu !== "2"}
          onClick={() => setShowCreateModal(true)}
        >
          Create Entitlement
        </button>
      </div>

      {showMenu && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded shadow-lg max-w-md w-full">
            <h3 className="text-lg font-bold mb-4">Modify Configuration</h3>
            <div className="mb-3">
              <label className="block text-sm font-medium mb-1">CPU</label>
              <select value={cpu} onChange={(e) => setCpu(e.target.value)} className="w-full border px-2 py-1 rounded">
                <option value="2">2</option>
                <option value="4">4</option>
                <option value="8">8</option>
              </select>
            </div>
            <div className="mb-3">
              <label className="block text-sm font-medium mb-1">SERVICEPACK</label>
              <select value={servicePack} onChange={(e) => setServicePack(e.target.value)} className="w-full border px-2 py-1 rounded">
                <option value="FORTICARE PREMIUM">FORTICARE PREMIUM</option>
                <option value="UTP">UTP</option>
                <option value="ENTERPRISE">ENTERPRISE</option>
                <option value="ATP">ATP</option>
              </select>
            </div>
            <div className="mb-3">
              <label className="block text-sm font-medium mb-1">VDOM</label>
              <select value={vdom} onChange={(e) => setVdom(e.target.value)} className="w-full border px-2 py-1 rounded">
                <option value="1">0</option>
                <option value="1">1</option>
                <option value="2">2</option>
              </select>
            </div>
            <div className="flex justify-between mt-4">
              <button
                className="px-4 py-2 bg-gray-300 rounded hover:bg-gray-400"
                onClick={() => setShowMenu(false)}
              >
                Cancel
              </button>
              <button
                className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
                onClick={() => setShowSubmitModal(true)}
              >
                Submit
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create Entitlement Confirmation Modal */}
      <Transition appear show={showCreateModal} as={Fragment}>
        <Dialog as="div" className="fixed inset-0 z-50 overflow-y-auto" onClose={() => setShowCreateModal(false)}>
          <div className="min-h-screen px-4 text-center">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0"
              enterTo="opacity-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100"
              leaveTo="opacity-0"
            >
              <Dialog.Overlay className="fixed inset-0 bg-black bg-opacity-30" />
            </Transition.Child>

            {/* This element is to trick the browser into centering the modal contents. */}
            <span className="inline-block h-screen align-middle" aria-hidden="true">&#8203;</span>

            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <div className="inline-block w-full max-w-md p-6 my-8 overflow-hidden text-left align-middle transition-all transform bg-white shadow-xl rounded-lg">
                <Dialog.Title as="h3" className="text-lg font-medium leading-6 text-gray-900">
                  Confirm Create Entitlement
                </Dialog.Title>
                <div className="mt-2">
                  <p>Are you sure you want to create an entitlement?</p>
                </div>

                <div className="mt-4 flex justify-end gap-2">
                  <button
                    type="button"
                    className="px-4 py-2 bg-gray-300 rounded hover:bg-gray-400"
                    onClick={() => setShowCreateModal(false)}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                    onClick={handleCreateEntitlement}
                  >
                    Confirm
                  </button>
                </div>
              </div>
            </Transition.Child>
          </div>
        </Dialog>
      </Transition>

      {/* Submit Changes Confirmation Modal */}
      <Transition appear show={showSubmitModal} as={Fragment}>
        <Dialog as="div" className="fixed inset-0 z-50 overflow-y-auto" onClose={() => setShowSubmitModal(false)}>
          <div className="min-h-screen px-4 text-center">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0"
              enterTo="opacity-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100"
              leaveTo="opacity-0"
            >
              <Dialog.Overlay className="fixed inset-0 bg-black bg-opacity-30" />
            </Transition.Child>

            <span className="inline-block h-screen align-middle" aria-hidden="true">&#8203;</span>

            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <div className="inline-block w-full max-w-md p-6 my-8 overflow-hidden text-left align-middle transition-all transform bg-white shadow-xl rounded-lg">
                <Dialog.Title as="h3" className="text-lg font-medium leading-6 text-gray-900">
                  Confirm Submit Changes
                </Dialog.Title>
                <div className="mt-2">
                  <p>Are you sure you want to submit the changes?</p>
                </div>

                <div className="mt-4 flex justify-end gap-2">
                  <button
                    type="button"
                    className="px-4 py-2 bg-gray-300 rounded hover:bg-gray-400"
                    onClick={() => setShowSubmitModal(false)}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
                    onClick={handleSubmitChanges}
                  >
                    Confirm
                  </button>
                </div>
              </div>
            </Transition.Child>
          </div>
        </Dialog>
      </Transition>
    </div>
  );
}