import React, { useContext } from "react";
import { toast, ToastContainer } from "react-toastify";
import 'react-toastify/dist/ReactToastify.css';
import { VITE_BACKEND_HOST } from "../config";
import { useSession } from "../context/SessionContext";
import { Dialog } from '@headlessui/react';
import { Fragment, useState } from 'react';

export default function FortiFlexEntitlementCard({ entitlement }) {
  const { fortiflex_config_types } = useSession();
  const configType = fortiflex_config_types?.find(cfg => String(cfg.id) === String(entitlement.configId))?.type || "FortiFlex Entitlement";

  const [actionModal, setActionModal] = useState({ isOpen: false, type: null, endpoint: "", label: "" });
  const [azureModalOpen, setAzureModalOpen] = useState(false);

  return (
    <div className="border rounded shadow p-4 bg-white space-y-2">
      <div className="font-bold text-red-600">{configType}: {entitlement.description}</div>
      <div><strong>Serial Number:</strong> {entitlement.serialNumber}</div>
      <div><strong>Status:</strong> {entitlement.status}</div>
      <div><strong>Token:</strong> {entitlement.token}</div>
      <div><strong>Token Status:</strong> {entitlement.tokenStatus}</div>
      <div><strong>Config ID:</strong> {entitlement.configId}</div>
      <div><strong>Account ID:</strong> {entitlement.accountId}</div>
      <div><strong>Start:</strong> {new Date(entitlement.startDate).toLocaleString()}</div>
      <div><strong>End:</strong> {new Date(entitlement.endDate).toLocaleString()}</div>

      {entitlement.status === "EXPIRED" || entitlement.status === "STOPPED" ? (
        <button
          className="mt-2 bg-green-600 text-white px-4 py-2 rounded mr-2"
          onClick={() =>
            setActionModal({ isOpen: true, type: "start", endpoint: "/api/fortiflex/entitlements/reactivate", label: "start" })
          }
        >
          Start
        </button>
      ) : entitlement.status === "ACTIVE" ? (
        <button
          className="mt-2 bg-red-600 text-white px-4 py-2 rounded mr-2"
          onClick={() =>
            setActionModal({ isOpen: true, type: "stop", endpoint: "/api/fortiflex/entitlements/stop", label: "stop" })
          }
        >
          Stop
        </button>
      ) : null}

      <button
        className={`mt-2 px-4 py-2 rounded ${entitlement.tokenStatus === "NOTUSED" ? "bg-blue-600 text-white" : "bg-gray-300 text-gray-600 cursor-not-allowed"}`}
        disabled={entitlement.tokenStatus !== "NOTUSED"}
        onClick={() => setAzureModalOpen(true)}
      >
        Launch Azure VM
      </button>

      {/* Action Modal */}
      <Dialog open={actionModal.isOpen} onClose={() => setActionModal({ ...actionModal, isOpen: false })} as={Fragment}>
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-30">
          <Dialog.Panel className="bg-white p-6 rounded shadow-md space-y-4">
            <Dialog.Title className="text-lg font-semibold">Confirm {actionModal.label}</Dialog.Title>
            <p>Are you sure you want to {actionModal.label} this entitlement?</p>
            <div className="flex justify-end space-x-3">
              <button
                className="px-4 py-2 bg-gray-300 rounded"
                onClick={() => setActionModal({ ...actionModal, isOpen: false })}
              >
                Cancel
              </button>
              <button
                className="px-4 py-2 bg-blue-600 text-white rounded"
                onClick={async () => {
                  try {
                    const res = await fetch(`${VITE_BACKEND_HOST}${actionModal.endpoint}`, {
                      method: "PUT",
                      headers: { "Content-Type": "application/json" },
                      credentials: "include",
                      body: JSON.stringify({ serialNumber: entitlement.serialNumber }),
                    });
                    if (!res.ok) throw new Error(`Failed to ${actionModal.label} entitlement`);
                    toast.success(`Entitlement ${actionModal.label}ed successfully!`);
                    setActionModal({ ...actionModal, isOpen: false });
                    setTimeout(() => window.location.reload(), 1500);
                  } catch (error) {
                    console.error("Action failed:", error);
                    toast.error(`Failed to ${actionModal.label} entitlement.`);
                  }
                }}
              >
                Confirm
              </button>
            </div>
          </Dialog.Panel>
        </div>
      </Dialog>

      {/* Azure VM Modal */}
      <Dialog open={azureModalOpen} onClose={() => setAzureModalOpen(false)} as={Fragment}>
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-30">
          <Dialog.Panel className="bg-white p-6 rounded shadow-md space-y-4">
            <Dialog.Title className="text-lg font-semibold">Launch Azure VM</Dialog.Title>
            <p>Are you sure you want to launch the Azure VM using this entitlement?</p>
            <p className="text-red-600 font-bold">***PLEASE DO NOT LAUNCH MORE THAN ONCE***</p>
            <div className="flex justify-end space-x-3">
              <button
                className="px-4 py-2 bg-gray-300 rounded"
                onClick={() => setAzureModalOpen(false)}
              >
                Cancel
              </button>
              <button
                className="px-4 py-2 bg-blue-600 text-white rounded"
                onClick={async () => {
                  try {
                    const res = await fetch(`${VITE_BACKEND_HOST}/api/azuremagic`, {
                      method: "POST",
                      headers: { "Content-Type": "application/json" },
                      credentials: "include",
                      body: JSON.stringify({ flexentitlementtoken: entitlement.token }),
                    });
                    if (!res.ok) throw new Error("Failed to launch Azure VM");
                    toast.success("Azure VM launched successfully!");
                    setAzureModalOpen(false);
                    setTimeout(() => window.location.reload(), 1500);
                  } catch (error) {
                    console.error("Azure VM launch failed:", error);
                    toast.error("Failed to launch Azure VM.");
                  }
                }}
              >
                Confirm
              </button>
            </div>
          </Dialog.Panel>
        </div>
      </Dialog>
    </div>
  );
}