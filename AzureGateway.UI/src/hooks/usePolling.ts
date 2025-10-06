import { useState, useEffect, useRef } from 'react';

interface PollingResult<T> {
    data: T | null;
    loading: boolean;
    error: any;
    refresh: () => Promise<void>;
    startPolling: () => void;
    stopPolling: () => void;
}

const usePolling = <T>(
    asyncFunction: () => Promise<T>, 
    interval: number = 5000, 
    immediate: boolean = true
): PollingResult<T> => {
    const [data, setData] = useState<T | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    const [error, setError] = useState<any>(null);
    const intervalRef = useRef<NodeJS.Timeout | null>(null);
    const mountedRef = useRef<boolean>(true);

    const pollData = async (): Promise<void> => {
        if (!mountedRef.current) return;

        try {
            setLoading(true);
            setError(null);
            const result = await asyncFunction();

            if (mountedRef.current) {
                setData(result);
            }
        } catch (err) {
            if (mountedRef.current) {
                setError(err);
            }
        } finally {
            if (mountedRef.current) {
                setLoading(false);
            }
        }
    };

    const startPolling = (): void => {
        if (intervalRef.current) return;

        if (immediate) {
            pollData();
        }

        intervalRef.current = setInterval(pollData, interval);
    };

    const stopPolling = (): void => {
        if (intervalRef.current) {
            clearInterval(intervalRef.current);
            intervalRef.current = null;
        }
    };

    const refreshData = (): Promise<void> => {
        return pollData();
    };

    useEffect(() => {
        mountedRef.current = true;
        startPolling();

        return () => {
            mountedRef.current = false;
            stopPolling();
        };
    }, [interval]);

    return {
        data,
        loading,
        error,
        refresh: refreshData,
        startPolling,
        stopPolling,
    };
};

export default usePolling;
